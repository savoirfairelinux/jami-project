"""
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Olivier Soldano <olivier.soldano@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
"""

import sys
import xml.etree.ElementTree as ET
from xml.dom import minidom
import datetime
from email.utils import formatdate


def sameDate(timestamp, pub):
    date1 = timestamp.split()
    date2 = pub.text.split()
    return date1[:4] == date2[:4]

def insertNewPackage(parent_element, title, attrib):
    now = datetime.datetime.now()

    new_item = ET.Element("item")

    titre = ET.SubElement(new_item,"titre")
    titre.text = title + now.strftime("%Y/%m/%d %H:%M")

    pubDate = ET.SubElement(new_item, "pubDate")
    pubDate.text = formatdate()

    enclosure = ET.SubElement(new_item, "enclosure", attrib=attrib)

    parent_element.insert(4,new_item)


if __name__ == "__main__":
    now = datetime.datetime.now()
    now_timestamp = formatdate() # rfc 2822
    sparkle_file = sys.argv[1]
    title = sys.argv[2]
    url = sys.argv[3]
    os = sys.argv[4]
    length = sys.argv[5]
    ET.register_namespace('sparkle','http://www.andymatuschak.org/xml-namespaces/sparkle')
    namespace = {'sparkle' : 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
    tree = ET.parse(sparkle_file)
    channel = tree.find("channel")
    attrib = {'url' : url,
              'sparkle:version' : now.strftime("%Y%m%d"),
              'sparkle:shortVersionString' : "nightly-" + now.strftime("%Y%m%d"),
              'sparkle:os' : os,
              'length' : length,
              'type' : "application/octet-stream"
    }

    # remove all publications of the same day (but not same os)
    for item in tree.findall(".//item"):
        if sameDate(now_timestamp, item.find("pubDate")) and not\
        item.find("./enclosure[@sparkle:os='%s']" % os, namespace) is None:
            channel.remove(item)

    insertNewPackage(channel, title, attrib)

    # Pretty printing with xml dom
    str_tree = ET.tostring(tree.getroot(),encoding='utf-8').decode('utf-8').replace('\n','').replace('\r','')
    reparsed_doc = minidom.parseString(str_tree)
    xml_out = open(sparkle_file,"wb")
    xml_out.write(reparsed_doc.toprettyxml(indent='  ', newl='\n',encoding="utf-8"))
    xml_out.close()
