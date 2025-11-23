pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property real cpu_temp: 0
    property var previousCpuStats

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }

    Timer {
        interval: 1
        running: true 
        repeat: true
        onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

                // Try reading common sysfs/hwmon temperature files first (faster,
                // avoids spawning a shell). If those are empty, fall back to the
                // probe process below.
                var ttxt = ""
                if (typeof fileTempThermal !== "undefined") {
                    try { fileTempThermal.reload() } catch (e) {}
                    ttxt = (fileTempThermal.text() || "").trim()
                }
                if ((!ttxt || ttxt.length === 0) && typeof fileTempHwmon !== "undefined") {
                    try { fileTempHwmon.reload() } catch (e) {}
                    ttxt = (fileTempHwmon.text() || "").trim()
                }

                if (ttxt && ttxt.length > 0) {
                    var t = parseFloat(ttxt)
                    if (!isNaN(t)) {
                        if (t > 1000) t = t / 1000
                        root.cpu_temp = t
                    }
                } else {
                    if (typeof readCpuTempProc !== "undefined") {
                        try { readCpuTempProc.start() } catch (e) {}
                    }
                }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    // Common locations for CPU temperature readings
    FileView { id: fileTempThermal; path: "/sys/class/thermal/thermal_zone0/temp" }
    FileView { id: fileTempHwmon; path: "/sys/class/hwmon/hwmon0/temp1_input" }

    Process {
        id: findCpuMaxFreqProc
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }

    // Process to probe common sysfs/hwmon temperature files and output the first
    // readable temperature. The Timer triggers `readCpuTempProc.start()` each
    // update interval so we keep `cpu_temp` updated.
    Process {
        id: readCpuTempProc
        running: false
        command: ["bash", "-c",
                  "for f in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do \
                       if [ -f \"$f\" ]; then cat \"$f\" && exit 0; fi; \
                   done; echo"]
        stdout: StdioCollector {
            id: outputTempCollector
            onStreamFinished: {
                var txt = outputTempCollector.text.trim()
                if (txt.length > 0) {
                    var t = parseFloat(txt)
                    if (!isNaN(t)) {
                        // If value looks like millidegrees, convert to degrees.
                        if (t > 1000) t = t / 1000
                        root.cpu_temp = t
                    }
                } else {
                    root.cpu_temp = 0
                }
            }
        }
    }

}
