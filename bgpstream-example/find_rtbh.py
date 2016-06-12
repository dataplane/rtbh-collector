#!/usr/bin/env python

# docs at bgpstream.caida.org
from _pybgpstream import BGPStream, BGPRecord, BGPElem
from collections import defaultdict

# export LD_LIBRARY_PATH="/usr/local/lib"

# Create a new bgpstream instance and a reusable bgprecord instance
stream = BGPStream()
rec = BGPRecord()

# Consider RRC12 
stream.add_filter('collector','rrc12')

# Consider RIBs dumps only
# stream.add_filter('record-type','ribs')

# Consider this time interval:
# Sat, 01 Aug 2015 7:50:00 GMT -  08:10:00 GMT
stream.add_interval_filter(1438415400,1438416600)

# Start the stream
stream.start()

# Get next record
while(stream.get_next_record(rec)):
    elem = rec.get_next_elem()
    while(elem):
        # only consider RIBs entries and Announcement messages
        if elem.type in ["R", "A"]:
            if 'next-hop' in elem.fields:
                # dec-ix blackholing next hop
                if elem.fields['next-hop'] == "80.81.193.66":
                    origin_as = ""
                    ases = elem.fields["as-path"].split()
                    if len(ases) > 0:
                        # get the origin AS
                        origin_as = ases[-1]
                        print "DE-CIX", elem.fields["prefix"], origin_as, elem.time
                    else:
                        # weird!
                        continue
        elem = rec.get_next_elem()
