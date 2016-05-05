Connecting Ring contacts to LDAP
================================

It is possible for Ring to search contacts in an LDAP directory. At the moment, this is only possible with the Gnome client. This is done by configuring gnome-contacts and evolution to search LDAP for contacts.


Connecting gnome-contacts to LDAP
#################################

1. Open Evolution
2. From the contacts tab, right click and select New Address Book

3. Fill the requested information **depending on your LDAP configuration**. Here is an example:


Connecting to LDAP section:
---------------------------

========================================== =============================
   Field                                            Value
========================================== =============================
**Type**                                   On LDAP Servers
**name**                                   <choose a name>
**Autocomplete with this address book**    checked
**server**                                 hostname of your LDAP server
**port**                                   port of your LDAP server
**Authentication Method**                  Using distinguished name (DN)
**Authentication Username**                <ldap username>
========================================== =============================

Using LDAP section:
-------------------

================================= =============================
      Field                                 Value
================================= =============================
**Search base**                   ou=Users,dc=enterprise,dc=net
**Search Scope**                  Subtree
**Download limit**                100
**Browse until limit is reached** checked
================================= =============================

4. Launch gnome-contacts. You should be asked for your LDAP password and the LDAP contacts will appear.

5. Launch Ring and your LDAP contacts will be shown.
