#!/usr/bin/env python
# -*- encoding: utf-8; py-indent-offset: 4 -*-

unit_info["Mbits/s"] = {
    "title": _("MBits per second"),
    "symbol": _("Mbits/s"),
    "render": lambda v: cmk.utils.render.physical_precision(v, 2, _("Mbit/s")),
    "graph_unit": lambda v: physical_precision_list(v, 2, _("Mbit/s")),
}


metric_info["download"] = {
    "title": _("Download"),
    "unit": "Mbits/s",
    "color": "#00e060",
}

metric_info["upload"] = {
    "title": _("Upload"),
    "unit": "Mbits/s",
    "color": "#0080e0",
}

graph_info["bandwidth_translated_all"] = {
    "title": _("Bandwidth"),
    "metrics": [
        ("download", "area"),
        ("upload", "-area"),
    ],
}
graph_info["bandwidth_translated_down"] = {
    "title": _("Bandwidth Download"),
    "metrics": [
        ("download", "area"),
    ],
}

graph_info["bandwidth_translated_up"] = {
    "title": _("Bandwidth Upload"),
    "metrics": [
        ("upload", "area"),
    ],
}

perfometer_info.append({
    "type"        : "stacked",
    "perfometers" : [
        {
            "type"          : "linear",
            "segments"      : [ "download" ],
            "total"         : 20,
        },
        {
            "type"          : "linear",
            "segments"      : [ "upload" ],
            "total"         : 5,
        }
    ],
})
