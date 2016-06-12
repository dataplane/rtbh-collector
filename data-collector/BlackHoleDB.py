# NANOG Hackathon




import time
import psycopg2

# info at http://initd.org/psycopg/docs/usage.html


class BlackHoleDb(object):
    """ Connect to the blackholing database
    """

    def _connect(self):
        # create a connection to the database
        self.__conn = psycopg2.connect("dbname=hackathon user=hack")

    def __init__(self):
        """ Connect to the database
        """
        self.__conn = None
        self._connect()

    def insert_data(self, data_source, blackholed_pfx, origin_as, epoch_ts):
        """ Insert a new entry into the database

        :param data_source:
        :param blackholed_pfx:
        :param origin_as:
        :param epoch_ts:
        :return:
        """
        db_ts= time.strftime('%m/%d/%Y %H:%M:%S', time.gmtime(epoch_ts))

        if not self.__conn:
            self._connect()

        cur = self.__conn.cursor()
        cur.execute("INSERT INTO blackhole (data_source, route, origin, stamp) VALUES (%s, %s, %s, %s)",
            (data_source, blackholed_pfx, origin_as, db_ts))

        # Make the changes to the database persistent
        self.__conn.commit()

        # close communication with the database
        cur.close()

    def _close(self):
        """
        Close communication with the database
        :return:
        """
        self.__conn.close()
        self.__conn = None


    def get_blackholed(self, time_start=None, time_end=None, ip=None, origin_as=None):
        """
        Return the the information that match the filter
        :param time_start:
        :param time_end:
        :param ip:
        :param origin_as:
        :return:
        """

        # build the query
        query = "SELECT * from blackhole WHERE "

        if time_start:
            query += " extract(epoch from stamp) >= {} AND ".format(time_start)

        if time_end:
            query += " extract(epoch from stamp) <= {} AND ".format(time_end)

        if ip:
            # <<= is contained within or equals inet , e.g.,  '192.168.1/24' <<= inet '192.168.1/24'
            query += " '{}' <<= route AND ".format(ip)

        if origin_as:
            query += " origin = {} AND ".format(origin_as)

        # last part of the query
        query += " 1 = 1 "
        query += "order by stamp, origin, route;"

        print query

        # read from db
        if not self.__conn:
            self._connect()

        cur = self.__conn.cursor()
        # execute query
        cur.execute(query)
        # and fetch results
        res = cur.fetchall()
        cur.close()

        return res



