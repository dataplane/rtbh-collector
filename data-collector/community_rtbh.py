#!/usr/bin/env python

# docs at bgpstream.caida.org

import sys
from BlackHoleDB import BlackHoleDb
from _pybgpstream import BGPStream, BGPRecord, BGPElem

communities = {
    "NetIX": [{65499: 999}],
    "KPN": [{286: 66}],
    "AT&T": [{7018: 86}],
    "TiNet": [{3257: 2666}],
    "Hurricane Electric": [{6939: 666}],
    "Level3": [{3356: 9999}],
    "MTS Allstream": [{15290: 9999}],
    "Qwest": [{209: 2}],
    "Sprint": [{1239: 66}],
    "Verizon": [{701:9999}],
    "Comcast": [{7922:666}],
    "i3d.net": [{49544:666}],
    "XO": [{2828:1650}],
    "Zayo": [{6461:5990}],
    "Hibernia": [{5580:666}],
    "Verizon": [{701:9999}],
    "C&W": [{1273:666}]
}


def contains_rtbh_community(comm_attr):
    global communities

    for c in comm_attr:
        for data_source in communities:
            if c["asn"] in communities[data_source]:
                if c["value"] in communities[data_source][c["asn"]]:
                    print "found"
                    # blackholing community found
                    return data_source
    return None


# get connection to database

bh_db = BlackHoleDb()

# export LD_LIBRARY_PATH="/usr/local/lib"

# Create a new bgpstream instance and a reusable bgprecord instance
stream = BGPStream()
rec = BGPRecord()

# Consider multi hop collectors
stream.add_filter('collector','rrc00')
stream.add_filter('collector','rrc00')
stream.add_filter('collector','route-views2')

# all data with community attributes
stream.add_filter('community','*:*')

# Consider RIBs dumps only
stream.add_filter('record-type','ribs')

# One rib per day
stream.add_rib_period_filter(3600*24)

# Consider this time interval: May 2016
stream.add_interval_filter(1462060800,1464739200)

# Start the stream
stream.start()

sys.stderr.write("Reading BGP Data\n")

# Get next record
while(stream.get_next_record(rec)):
    elem = rec.get_next_elem()
    while(elem):
        # only consider RIBs entries and Announcement messages
        if elem.type in ["R", "A"]:
            data_source = contains_rtbh_community(elem.fields['communities'])
            if data_source:
                origin_as = ""
                ases = elem.fields["as-path"].split()
                if len(ases) > 0:
                    # get the origin AS
                    origin_as = ases[-1]
                    bh_db.insert_data(data_source, elem.fields["prefix"], origin_as, elem.time)
                    print data_source, elem.fields["prefix"], origin_as, elem.time
                else:
                    # weird!
                    continue
        elem = rec.get_next_elem()

sys.stderr.write("Done\n")