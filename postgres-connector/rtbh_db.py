

import sys
import time
import psycopg2

# info at http://initd.org/psycopg/docs/usage.html

conn = psycopg2.connect("dbname=chiara user=chiara")
cur = conn.cursor()


# my data
data_ts = 817398174




db_timestamp = time.strftime('%m/%d/%Y %H:%M:%S', time.gmtime(data_ts))


cur.execute("INSERT INTO blackhole (data_source, route, origin, stamp) VALUES (%s, %s, %s, %s)",
            ("decix","1.1.2.3/32", "3356", db_timestamp))

# Make the changes to the database persistent
conn.commit()


# read from db
cur.execute("SELECT * FROM blackhole;")
print cur.fetchone()

# Close communication with the database
cur.close()
conn.close()
