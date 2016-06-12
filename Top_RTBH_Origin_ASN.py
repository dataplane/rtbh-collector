import sys
import time
import site
import psycopg2
import subprocess as sub

# info at http://initd.org/psycopg/docs/usage.html


class Top_RTBH_Origin_ASN(object):
    conn = psycopg2.connect("dbname=hackathon user=hack")
    cur = conn.cursor()

# read from db
    cur.execute("SELECT origin, count(origin) FROM blackhole GROUP BY origin ORDER BY count(origin) DESC;")
    for row in cur:
        as_name = sub.Popen(['whois -h whois.cymru.com " -f AS' + str(row[0]) + '"'], shell=True, stdout=sub.PIPE,stderr=sub.PIPE)
        p_as_name, err = as_name.communicate()
        print "AS: " + str(row[0]) + ", Count: " + str(row[1]) + ", AS Name: " + str(p_as_name)

# Close communication with the database
    cur.close()
    conn.close()

tops = Top_RTBH_Origin_ASN()
