#!/usr/bin/env python

# docs at bgpstream.caida.org

import sys
from BlackHoleDB import BlackHoleDb
from _pybgpstream import BGPStream, BGPRecord, BGPElem


data_source = "DE-CIX"
sys.stderr.write("Inserting data from DE-CIX\n")
# get connection to database

bh_db = BlackHoleDb()

# export LD_LIBRARY_PATH="/usr/local/lib"

# Create a new bgpstream instance and a reusable bgprecord instance
stream = BGPStream()
rec = BGPRecord()

# Consider RRC12 
stream.add_filter('collector','rrc12')

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
            if 'next-hop' in elem.fields:
                # dec-ix blackholing next hop
                if elem.fields['next-hop'] == "80.81.193.66" or elem.fields['next-hop'] == "2001:7f8::1a27:66:95":
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