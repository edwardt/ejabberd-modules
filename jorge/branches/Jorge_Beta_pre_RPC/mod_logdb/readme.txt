mod_logdb by Oleg Palij
-----------------------

*NOTE* - Jorge is compatible only with the distributed mod_logdb. Please follow instruction below carefully. 
Jorge try to always be up-to-date with the latest mod_logdb but there still can be some delays.

Instalation instruction:

1) Grab ejabberd SVN revision 861
2) Patch sources of ejabberd using "patch" tool 
   (f.e: patch -p0 < patch-src-mod_logdb_svn)
2) Setup mysql5 database (dbname, username, etc...). 
   Db schema will be automaticaly setup during mod_logdb startup.
3) Edit config of your ejabberd server by adding following lines into modules section:
4) If you are using mysql5 backend with procedural language *you must patch* mysql driver with provided patch: userflags.diff, and add user priviledges for creating views (CREATE VIEW)

{modules, [
  ...
  {mod_logdb,
    [{vhosts, [{"your_xmpp_server", mysql5}]},
     {dbs, [{mysql5, [{user, "db_username"},
                     {password, "db_password"},
		     {server, "ip_of_the_db_server"},
		     {port, 3306},
		     {db, "db_name"}
		    ]
      }]},
     {groupchat, none},
     {purge_older_days, never},
     {ignore_jids, ["example@jid.pl", "example2@jid.pl"]},
     {dolog_default, false}
    ]
  },
  ...
]}.

And for ad-hoc commands, add on the top of the config file:

{access, mod_logdb, [{allow, all}]}.
{access, mod_logdb_admin, [{allow, admin}]}.

5) Restart the server
6) Have fun

For further info consult mod_logdb manual.

Note for admins who use clustered setup: you need to install mod_logdb on each ejabberd node. 
Multiple mod_logdb sessions can share database access without any problems.
