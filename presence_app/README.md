Presence_App
============

Presence App lets client to query the "presence" information of a ejabberd cluster. Right now it outputs users online list and the total number of online users. 

#####This is a beta version

###Background
Ejabberd keeps track of live sessions in 2 tables (http_bind and session). Entries are created on session creation, deleted on session destruction.
• http_bind table: only for sessions created via BOSH.  Sessions created outside of BOSH will not 
  be bookkept in this table,

  It keeps track of connection process rather than user info. 

• session table: for xmpp session created. Keeps track of Jid, server, resource info etc. It has no knowledge of BOSH. session_counter keeps total number of active sessions.

There is no direct “syncing” mechanism from these 2 tables. They are only linked by internal ejabberd events chains.

There are additional checks like “privacy/subscribe/unsubscribe” check  or entries creation on session table. There is no such check when during entry creation in http_bind table.

### No direct querying from Ejabberd server. 
To help Ejabberd focus on "chatting", auxillary service is kept out of Ejabberd server operation. So the following focus:
• void direct querying presence data from ejabberd server directly. 
• focus to query from a slave nodes that ejabberd server will sync its data to (dirty)

### Approach
• Our service will act like “slave node” to ejabberd mnesia cluster. Data querying will be against the db owned by us. The concept is veyr much the same as clustering Ejabberd Server except that we only insterested in session table.

•  Slave mnesia nodes will be of type ram_copies, so they won’t be part of mnesia data reconciliations in case of network partition. Also,  presence data has very short shelf life, not worth to save any on disk.

• All the data synchronization/replication and the level of data consistency guarantees etc will be dealt by mnesia. Scalability of load on data replication/sync etc should not be worse than ejabberd.

• Reading will be dirty read. There is no write to mnesia from my end.

###Usage scenario
-------
* A live ejabberd server must be running 
* you need to ping put service first 
  For examnple: ejabberdctl live shell
  A = your@erlangnode
  net_adm:ping(A).
  You shall receive a pong, to inidcate Ejabberd server is able to reach your node.
* In your erlang service shell:
  start your app 
  B = your@ejbberd_server_node.
  user_presence_db:join(B).

  You shall see the application start reporting how many users are online and the list of users (example tells you that you have 2 users,
  usera and userb online):

18:28:12.386 [info] List of members online [{"usera","chat.dev0.spark.net"},{"userb","chat.dev0.spark.net"}]
18:28:17.387 [info] List of members online [{"usera","chat.dev0.spark.net"},{"userb","chat.dev0.spark.net"}]
18:28:17.387 [info] Total members online 2
18:28:22.388 [info] Total members online 2
18:28:22.388 [info] List of members online [{"usera","chat.dev0.spark.net"},{"userb","chat.dev0.spark.net"}]
18:28:27.389 [info] List of members online [{"usera","chat.dev0.spark.net"},{"userb","chat.dev0.spark.net"}]
18:28:27.389 [info] Total members online 2


