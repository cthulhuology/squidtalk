squidtalk
=========

An event driven message passing distributed object store 


Requirements
============

squidtalk uses a number of open source components to manage data. 

* Postgresql - for data storage
* RabbitMQ - for message passing
* Mojolicious - for socket connections
* Mozilla Persona - for authentication
* Perl - for gluing it all together

The SquidTalk Protocol
======================

squidtalk speaks a very simple text only protocol.  While it uses
persistent connections for messaging, it uses HTTP's methods for
consistency.  In order to make it easier to integrate into other
webtech, it uses JSON for data encapsulation.  Anyone familiar
with Redis's protocol will feel pretty at home.

CREATE
------

POST /&lt;domain&gt; [&lt;acl&gt;]

	Creates the specified domain if and only if it doesn't already exist

	If the optional ACL is supplied, it will fix the attributes of the 
	domain.  By default, the ACL specifies the domain:

		{ "create" : "$USER", "update" : "$USER",
		  "read" : ".*", "delete" : "$USER" }

POST /&lt;domain&gt;/&lt;bucket&gt; [&lt;acl&gt;]

	Creates the specified bucket if and only if it doesn't already exist.
	The user must have the "create" attribute on the given domain for the
	operation to succeed.

	The default ACL on the newly created bucket is as follows:	
		
		{ "create" : "$USER", "update" : ".*",
		  "read" : ".*", "delete" : "$USER" }

POST /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt; &lt;JSON&gt;
	
	Instantiates a new object with the given key, if and only if the key 
	doesn't exist already.  The value of the key will be the mandatory JSON
	payload.  This payload may be 0, '', [], or {} depending on the type of nil
	desired.	

POST /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt;/&lt;path&gt; &lt;JSON&gt;

	This will inject a new value into an existing object at the given path.
	If the key and path already exist, then no value will be created.


READ
----

GET /&lt;domain&gt;
	
	Returns a list of buckets associated with the given domain.

GET /&lt;domain&gt;/&lt;bucket&gt;

	Returns a list of keys associated with the given bucket.

GET /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt;

	Returns the JSON object associated with the key, and sets up
	a watch to notify the getter of any alterations to that key.

GET /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt;/&lt;path&gt;

	Returns the value associated with the given path.  The path
	is a '/' separated list of keys which may consist of strings
	and numbers.


UPDATE
------

PUT /&lt;domain&gt; &lt;acl&gt;

	Updates the ACL for the given domain.  The "update" attribute on the
	domain must have been specified for the connected user.  At least one
	user must have "update" access, and "$USER" will automatically be appended.

PUT /&lt;domain&gt;/&lt;bucket&gt; &lt;acl&gt;

	Updates the ACL on the given bucket.  The "update" attribute must be given to
	the connected user on the domain for this operation to succeed.  

PUT /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt; &lt;JSON&gt;

	Updates the value associated with the given key.  The user doing the update
	must have the "update" attribute available on the associated bucket.

PUT /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt;/&lt;path&gt; &lt;JSON&gt;

	Updates the value at the given path if and only if the given path already 
	exists.  The user must also have the "update" attribute on teh associated bucket
	for the operation to complete.

DELETE
------

DELETE /&lt;domain&gt;

	Deletes all of the buckets associated with the given domain.  The user must 
	have the "delete" attribute on the domain to delete the buckets.

DELETE /&lt;domain&gt;/&lt;bucket&gt;

	Deletes all of the keys associated with the given bucket.  The user must have
	the "delete" attribute on the bucket.

DELETE /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt;

	Deletes the given key and value from the bucket.  The user must have the "delete"
	attribute on the bucket to delete a key.  

DELETE /&lt;domain&gt;/&lt;bucket&gt;/&lt;key&gt;/&lt;path&gt;

	Deletes the value at the given path if and only if the path exists.  The user
	must have the "update" attribute on the bucket to delete a path.  This is not
	considered a deletion in the other sense of DELETE.


Access Control Lists
====================

One of the core features of squidtalk is the built in access controls.  Rather than 
leaving the security of the data entirely to the application, squidtalk enforces a
set of rules which prevent misbehavior by clients.

The access control list takes the form of a JSON object with the keys:

* "create" - post new domains, buckets, and keys
* "read" - get domains, buckets, and keys
* "update" - put domains, buckets, and keys
* "delete" - delete domains, buckets, and keys

These follow the typical CRUD application behaviors one would expect.  The mapping
to the protocol methods takes the occasional liberty, in order to ensure that 
behaviors which are effectively updates require the "update" capability.  By default,
the creator of a domain or bucket will retain full access to the entity in question.

In general, "read" and "update" should be more permissive than "create" and "delete".
The reason is that internally, a "read" or "update" does not destroy any data, or
produce any heavy overhead constructs.  Reads will never modify an existing value,
and updates will only produce a new time-series instance of the given key.  This allows
for non-destructive creation of new values.  Should a malicious application mutate the
state in an undesirable way, it is possible to recover.  "create" and "delete" attributes
on the other hand fundamentally alter the infrastructure.  The "create" operations provision
new resources and limit the possible future operations.  The "delete" operations permanently
remove data from the system, and will destory all history for a given entity.


