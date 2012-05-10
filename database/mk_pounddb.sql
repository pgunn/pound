--

CREATE TABLE config
	(
	id SERIAL PRIMARY KEY NOT NULL,
	name TEXT UNIQUE NOT NULL,
	value TEXT,
	avalues VARCHAR(10),
	description TEXT
	);

CREATE TABLE pathconfig
	( -- Might do something more with this...
	id SERIAL PRIMARY KEY NOT NULL,
	name TEXT UNIQUE NOT NULL,
	value TEXT,
	description TEXT
	);

CREATE TABLE theme
	( -- Header for actual theme data
	id SERIAL PRIMARY KEY NOT NULL,
	name VARCHAR(20) UNIQUE NOT NULL,
	description TEXT
	);


CREATE TABLE person
	(
	id SERIAL PRIMARY KEY,
	login VARCHAR(30) UNIQUE, -- Also used for shortname. Restricted form
	pass VARCHAR(30),
	name TEXT NOT NULL,
	weburl TEXT,
	descrip TEXT,
	can_wiki BOOLEAN,
	can_upload BOOLEAN default('f'),
	is_super BOOLEAN default('f'),
	sitetheme INTEGER references theme, -- What CSS theme user has for viewing the site
	picurl TEXT,
	validated BOOLEAN default('f')
	);

CREATE TABLE lj
	(
	id SERIAL PRIMARY KEY,
	username VARCHAR(30) NOT NULL,
	pass VARCHAR(30) NOT NULL
	);


CREATE TABLE blog
	(
	id SERIAL PRIMARY KEY,
	name VARCHAR(10) NOT NULL,
	title VARCHAR(50),
	author INTEGER REFERENCES person(id),
	comments BOOLEAN,
	anon_comments BOOLEAN,
	header_extra TEXT, -- Extra headers for blog
	blogimg TEXT,
	blogtype CHAR DEFAULT('b'), -- b for blog, c for comic
	ljid INTEGER REFERENCES lj(id)
	);


CREATE TABLE blogentry
	(
	id SERIAL PRIMARY KEY,
	blog INTEGER REFERENCES blog,
	private BOOLEAN,
	comments BOOLEAN, -- Allow tighter permissions than blog
	anon_comments BOOLEAN,
	zeit BIGINT NOT NULL, -- External timestamp
	title TEXT,
	body TEXT
	);

CREATE TABLE ljitem
	(
	id SERIAL PRIMARY KEY,
	beid INTEGER NOT NULL REFERENCES blogentry(id),
	itemid INTEGER NOT NULL
	);

CREATE TABLE blogcomment
	(
	id SERIAL PRIMARY KEY,
	zeit BIGINT NOT NULL, -- External timestamp
	author INTEGER, -- NULL if anon
	title TEXT,
	body TEXT,
	blogparent INTEGER references blogentry, -- Ultimate parent
	coc INTEGER references blogcomment, -- Comment on comment, NULL if not.
	blog INTEGER REFERENCES blog,
	sourceip VARCHAR(20) -- Enough to hold a simple dotted quad. Not IPv6 safe
	);

CREATE TABLE topic
	(
	id SERIAL PRIMARY KEY,
	name VARCHAR(20) NOT NULL,
	imgurl TEXT,
	descrip TEXT,
	blog INTEGER references blog(id) -- Each person creates their own topics
	);

CREATE TABLE entry_topic
	(
	id SERIAL PRIMARY KEY,
	entryid INTEGER NOT NULL REFERENCES blogentry,
	topicid INTEGER NOT NULL REFERENCES topic	
	);

CREATE TABLE entry_misc
	(
	id SERIAL PRIMARY KEY,
	entryid INTEGER NOT NULL REFERENCES blogentry,
	misctype VARCHAR(30) NOT NULL, -- e.g. music, mood, etc
	miscdata TEXT -- Hopefully doing this as TEXT isn't a mistake..
	);

CREATE TABLE wikentry
	(
	id SERIAL PRIMARY KEY,
	namespace TEXT,
	title TEXT NOT NULL,
	locked BOOLEAN default('f') -- No edits except by superuser
	);

CREATE TABLE wikventry
	( -- Versioned entry, actually has content
	id SERIAL PRIMARY KEY,
	entry INTEGER REFERENCES wikentry,
	version INTEGER NOT NULL,
	author INTEGER, -- NULL if anon
	cmt VARCHAR(100),
	data TEXT,
	sourceip VARCHAR(20) -- Enough to hold a simple dotted quad. Not IPv6 safe
	);

CREATE TABLE wikcomment
	(
	id SERIAL PRIMARY KEY,
	zeit BIGINT NOT NULL, -- External timestamp
	author INTEGER, -- NULL if anon
	body TEXT,
	wikparent INTEGER references wikentry, -- Ultimate parent
	coc INTEGER references wikcomment -- Comment on comment, NULL if not.
	);

CREATE TABLE dsource
	(
	id SERIAL PRIMARY KEY,
	key VARCHAR(15) NOT NULL, -- This is a "namespace"
	rule_simple BOOLEAN NOT NULL, 	-- If true, append link target to
					-- provided rule value, otherwise
					-- use parser (not yet implemented or designed)
	rule_value TEXT,
	magic BOOLEAN NOT NULL		-- True: Internal link, can do existence check
	);

CREATE TABLE timeimage
        (
        timeid SERIAL,
        name varchar(20) UNIQUE NOT NULL,
        starttime INTEGER NOT NULL,
        stoptime INTEGER NOT NULL,
        imageurl text,
	blogid integer
        );

CREATE TABLE weblogin
	(
	id SERIAL,
	userid INTEGER REFERENCES researcher(id) NOT NULL UNIQUE,
	expires INTEGER NOT NULL,
	mcookie VARCHAR(60) NOT NULL UNIQUE
	);

CREATE TABLE person_css
	(
	id SERIAL PRIMARY KEY NOT NULL,
	personid INTEGER REFERENCES person,
	csstype VARCHAR(10) NOT NULL, -- TAG, ID, or CLASS
	csselem VARCHAR(20) NOT NULL, -- Specific tag, id, or class
	cssprop VARCHAR(20) NOT NULL, -- Property we're setting for it
	cssval TEXT NOT NULL -- value
	);

CREATE TABLE themedata
	(
	id SERIAL PRIMARY KEY,
	themeid INTEGER REFERENCES theme NOT NULL,
	csstype VARCHAR(10) NOT NULL, -- See person_css for detail
	csselem VARCHAR(20) NOT NULL,
	cssprop VARCHAR(20) NOT NULL,
	cssval TEXT NOT NULL
	);

CREATE TABLE files
	( -- XXX Maybe eventually move variant into sep table to remove limits?
	id SERIAL PRIMARY KEY,
	name TEXT NOT NULL,
	namespace TEXT NOT NULL, -- 'wiki' for wiki, otherwise name of blog
	variant TEXT, -- e.g. "dims=16x16,foo=bar" for an image. Keys MUST be
			-- alphabetically sorted.
	creator INTEGER REFERENCES person,
	storetype VARCHAR(10), -- 'file', 'blob', or 'url'
	exturl TEXT, -- for use with URL
	filename TEXT, -- Only filled in if !stored_blob
	blobid oid, -- REFERENCES pg_largeobject(loid),
			-- For when it is stored as a blob.
			-- Postgres won't let me reference a system
			-- catalogue this way.
	timehere BIGINT NOT NULL, -- Unixtime this version was put up
	version INTEGER NOT NULL, -- We *CAN* store all versions of
				  -- everything. If we do is a policy decision
	filetype VARCHAR(10) NOT NULL, -- "img", "swf", "misc"
	mimetype VARCHAR(20) NOT NULL
	);

CREATE TABLE msgmeths
(
id SERIAL PRIMARY KEY NOT NULL,
uid INTEGER REFERENCES person NOT NULL, -- Note that this is not unique - a person can have multiple such prefs, will go to all set
method VARCHAR(10) NOT NULL, -- Yeah yeah, whatever. It's inefficient. Whatever. Present OK values are 'email', 'xmpp', 'web'
username VARCHAR(30), -- first part of username@host - used by email and xmpp so far
hostname VARCHAR(50), -- latter part of username@host - also used by email and xmpp so far
validreq TIMESTAMP,  -- When the user requested validation..
passkey VARCHAR(50), -- Generated when user registers a new notification method, user gets one notification through the method
                        -- asking them to go to an URL that contains this passkey, after which the method is marked as ok.
                        -- naturally, we need to add a handler for that. URL could be something like
                        -- /pound/notify/validate/$uid/$meth/passkey ?
valid BOOLEAN DEFAULT('f') NOT NULL -- prevent spam
);

CREATE TABLE messages 
(
id SERIAL PRIMARY KEY NOT NULL,
recipient INTEGER REFERENCES person NOT NULL,
class VARCHAR(20), -- Or should this be an integer? Hmm...
autodisarm BOOLEAN NOT NULL,
subject VARCHAR(80) NOT NULL,
body TEXT NOT NULL,
lastnagged TIMESTAMP
);



insert into timeimage(starttime, stoptime, name, imageurl, blogid) values (0, 359, 'Dawn', 'http://blog.dachte.org/time_dawn.jpg', 1);
insert into timeimage(starttime, stoptime, name, imageurl, blogid) values (360, 719, 'Morning', 'http://blog.dachte.org/time_morning.jpg', 1);
insert into timeimage(starttime, stoptime, name, imageurl, blogid) values (720, 1079, 'Evening', 'http://blog.dachte.org/time_evening.jpg', 1);
insert into timeimage(starttime, stoptime, name, imageurl, blogid) values (1080, 1440, 'Dusk', 'http://blog.dachte.org/time_dusk.jpg', 1);

INSERT INTO config(name,value, avalues, description) VALUES ('xmlfeed', 10, 'i[1-100]', 'How many entries to show in the default XML feeds');
INSERT INTO config(name,value, avalues, description) VALUES ('entries_per_archpage', 10, 'i[1-30]', 'How many entries are part of a blog archive page');
INSERT INTO config(name,value, avalues, description) VALUES ('wiki_public', 0, 'b', 'Is the Wiki editable by the public?');

INSERT INTO config(name,value, avalues, description) VALUES ('blogstatic', 'http://localhost', 't[URL]', 'Base URL (includes http part) for the server');
INSERT INTO config(name,value, avalues, description) VALUES ('main_blogname', 'dachte', 't', 'Shortname of the "main" blog (if any)');
INSERT INTO config(name,value, avalues, description) VALUES ('doing_frontpage', 0, 'b', 'Are we doing a frontpage pointing at all hosted blogs?');

INSERT INTO config(name,value, avalues, description) VALUES ('postguard', 1, 'b', 'Enable postguard? This blocks some spam but will block AOL and Tor users from posting');

--- Path config defaults
INSERT INTO pathconfig(name,value, description) VALUES ('notdonepage', 'notdone', 'Pathpart for not-done-yet page');

INSERT INTO pathconfig(name,value, description) VALUES ('cssdir', 'css', 'Pathpart for css components');
INSERT INTO pathconfig(name,value, description) VALUES ('sitecss', 'site.css', 'Pathpart for site css file');

INSERT INTO pathconfig(name,value, description) VALUES ('wikbase', 'wiki', 'Pathpart for wiki');

INSERT INTO pathconfig(name,value, description) VALUES ('blogbase', 'blog', 'Pathpart for blog component');
INSERT INTO pathconfig(name,value, description) VALUES ('rssblog', 'rss1', 'Pathpart for blog rss1 feeds');
INSERT INTO pathconfig(name,value, description) VALUES ('atomblog', 'atom', 'Pathpart for blog atom feeds');
INSERT INTO pathconfig(name,value, description) VALUES ('archivebase', 'archive', 'Pathpart for blog archives');
INSERT INTO pathconfig(name,value, description) VALUES ('personbase', 'people', 'Pathpart for person profiles');
INSERT INTO pathconfig(name,value, description) VALUES ('topicbase', 'topics', 'Pathpart for topics');
INSERT INTO pathconfig(name,value, description) VALUES ('entbase', 'entries', 'Pathpart for blog entries');
INSERT INTO pathconfig(name,value, description) VALUES ('combase', 'comments', 'Pathpart for blog comments');
INSERT INTO pathconfig(name,value, description) VALUES ('blogreply_base', 'reply_to_entry', 'Pathpart for blog reply pages');
INSERT INTO pathconfig(name,value, description) VALUES ('blogcommentreply_base', 'reply_to_comment', 'Pathpart for blog comment replies');
INSERT INTO pathconfig(name,value, description) VALUES ('blogreply_submitbase', 'blogreplypost', 'Pathpart for blog entry reply POSTs');
INSERT INTO pathconfig(name,value, description) VALUES ('blogcommentreply_submitbase', 'blogcommentreplypost', 'Pathpart for blog comment reply POSTs');
INSERT INTO pathconfig(name,value, description) VALUES ('listbase','list', 'Pathpart for blog entry list');

INSERT INTO pathconfig(name,value, description) VALUES ('loginpage', 'login', 'Pathpart for login page');
INSERT INTO pathconfig(name,value, description) VALUES ('catchloginpage', 'catchlogin', 'Pathpart for login submittal');
INSERT INTO pathconfig(name,value, description) VALUES ('logoutpage', 'logout', 'Pathpart for logout page');

INSERT INTO pathconfig(name,value, description) VALUES ('prefspage', 'prefs', 'Pathpart for user prefs');
INSERT INTO pathconfig(name,value, description) VALUES ('prefsubmit', 'prefsubmit', 'Pathpart for user pref POSTs');

INSERT INTO pathconfig(name,value, description) VALUES ('blogcfgpage', 'blogcfg', 'Pathpart for blog configuration');
INSERT INTO pathconfig(name,value, description) VALUES ('blogcfgsubmitpage', 'blog_config_submit', 'Pathpart for blog configuration POSTs');
INSERT INTO pathconfig(name,value, description) VALUES ('manage_topics', 'managetopics', 'Pathpart for blog topic management');
INSERT INTO pathconfig(name,value, description) VALUES ('manage_topics_submit', 'managetopics_submit', 'Pathpart for blog topic management POSTs');
INSERT INTO pathconfig(name,value, description) VALUES ('del_topics_page','deltopic', 'Pathpart for topic deletion');
INSERT INTO pathconfig(name,value, description) VALUES ('del_topics_page_post','deltopic_post', 'Pathpart for topic deletion POSTs');

INSERT INTO pathconfig(name,value, description) VALUES ('nentrypage', 'nentry', 'Pathpart for new blog entry');
INSERT INTO pathconfig(name,value, description) VALUES ('ncomicpage', 'ncomic', 'Pathpart for new comic entry');
INSERT INTO pathconfig(name,value, description) VALUES ('edentrypage', 'edentry', 'Pathpart for editing blog entries');
INSERT INTO pathconfig(name,value, description) VALUES ('entry_privtogglebase','etoggle', 'Pathpart for entry privilege toggling');

INSERT INTO pathconfig(name,value, description) VALUES ('newuser', 'newuser', 'Pathpart for account creation');
INSERT INTO pathconfig(name,value, description) VALUES ('newusersubmit', 'newusersubmit', 'Pathpart for account creation POSTs');

INSERT INTO pathconfig(name,value, description) VALUES ('filebase', 'files', 'Pathpart for file serving');
INSERT INTO pathconfig(name,value, description) VALUES ('manage_files_base', 'files_manage', 'Pathpart for managing files');
INSERT INTO pathconfig(name,value, description) VALUES ('upload_files_base', 'files_upload', 'Pathpart for uploading files');


INSERT INTO pathconfig(name,value, description) VALUES ('manage_messages', 'messages', 'Pathpart for managing messages');
INSERT INTO pathconfig(name,value, description) VALUES ('manage_messages_ackpage', 'ackmsg', 'Pathpart for acknowledging messages');
INSERT INTO pathconfig(name,value, description) VALUES ('add_messages', 'addmsg', 'Pathpart for adding messages');

