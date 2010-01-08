DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS usergroups CASCADE;
DROP TABLE IF EXISTS user_in_group CASCADE;
DROP TABLE IF EXISTS configure CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
--DROP TABLE IF EXISTS grouprelations CASCADE;
DROP TABLE IF EXISTS posts CASCADE;
DROP TABLE IF EXISTS authors CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS subscriptions_all CASCADE;
DROP TABLE IF EXISTS subscriptions_pauseid CASCADE;
DROP TABLE IF EXISTS tags CASCADE;
DROP TABLE IF EXISTS tag_cloud CASCADE;

DROP SEQUENCE IF EXISTS groups_id_seq;
DROP SEQUENCE IF EXISTS posts_id_seq;
DROP SEQUENCE IF EXISTS users_id_seq;
DROP SEQUENCE IF EXISTS usergroups_id_seq;
DROP SEQUENCE IF EXISTS authors_id_seq;
DROP SEQUENCE IF EXISTS subscriptions_id_seq;
DROP SEQUENCE IF EXISTS subscriptions_all_id_seq;
DROP SEQUENCE IF EXISTS subscriptions_pauseid_id_seq;
DROP SEQUENCE IF EXISTS tags_id_seq;

CREATE SEQUENCE users_id_seq;
CREATE SEQUENCE groups_id_seq;
CREATE SEQUENCE usergroups_id_seq;
CREATE SEQUENCE posts_id_seq;
CREATE SEQUENCE authors_id_seq;
CREATE SEQUENCE subscriptions_id_seq;
CREATE SEQUENCE subscriptions_all_id_seq;
CREATE SEQUENCE subscriptions_pauseid_id_seq;
CREATE SEQUENCE tags_id_seq;

CREATE TABLE authors (
			id               INTEGER PRIMARY KEY DEFAULT nextval('authors_id_seq'::regclass),
			pauseid          VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE users (
			id                 INTEGER PRIMARY KEY DEFAULT nextval('users_id_seq'::regclass),
			username           VARCHAR(25) UNIQUE NOT NULL,
			sha1               CHAR(27)    NOT NULL,
			email              VARCHAR(100) UNIQUE NOT NULL,
			fname              VARCHAR(100),
			lname              VARCHAR(100),
			update_on_new_user VARCHAR(1),
			pauseid            INTEGER,
--			status             INTEGER,
			registration_date  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
			last_seen          TIMESTAMP,
			FOREIGN KEY (pauseid) REFERENCES authors(id)
);

CREATE TABLE usergroups (
			id               INTEGER PRIMARY KEY DEFAULT nextval('usergroups_id_seq'::regclass),
			name             VARCHAR(255) UNIQUE NOT NULL
);


CREATE TABLE user_in_group (
			uid               INTEGER NOT NULL,
			gid               INTEGER NOT NULL,
			FOREIGN KEY (uid)  REFERENCES users(id),
			FOREIGN KEY (gid)  REFERENCES usergroups(id)
);

CREATE TABLE configure (
			field             VARCHAR(255) UNIQUE NOT NULL,
			value             VARCHAR(255) NOT NULL
);


CREATE TABLE groups (
			id               INTEGER PRIMARY KEY DEFAULT nextval('groups_id_seq'::regclass),
			name             VARCHAR(255) UNIQUE NOT NULL,
			status           INTEGER,
			gtype            INTEGER NOT NULL,
			version          VARCHAR(100),
			pauseid          INTEGER, -- should be NOT NULL but there are entries in the database with null, TODO create a hash of the correct values before!
			rating           VARCHAR(10),	
			review_count     INTEGER NOT NULL DEFAULT 0,
			FOREIGN KEY (pauseid)  REFERENCES authors(id)
);
-- TODO check again all the fields including the status fields, are they really NULL ?

--CREATE TABLE grouprelations (
--			parent            INTEGER NOT NULL,
--			child             INTEGER NOT NULL,
--			FOREIGN KEY (parent) REFERENCES groups(id),
--			FOREIGN KEY (child) REFERENCES groups(id)
--);

-- grouprelations defined which group belongs to which other group, 
-- In the application level we'll have to implement the restriction so 
-- Global group will have no parent
-- Fields will have Global as parent
-- Distributions will have Fields as parent one child can have several parents
-- Modules (if added) will have Distributions as parents

CREATE TABLE posts (
			id               INTEGER PRIMARY KEY DEFAULT nextval('posts_id_seq'::regclass),
			gid              INTEGER NOT NULL,
			uid              INTEGER NOT NULL,
			parent           INTEGER,
			thread           INTEGER,
			hidden           BOOLEAN,
			subject          VARCHAR(255) NOT NULL,
			text             TEXT,
			date             TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
			FOREIGN KEY (gid) REFERENCES groups(id),
			FOREIGN KEY (uid) REFERENCES users(id),
			FOREIGN KEY (parent) REFERENCES posts(id)
);


CREATE TABLE subscriptions (
			id               INTEGER PRIMARY KEY DEFAULT nextval('subscriptions_id_seq'::regclass),
			uid              INTEGER NOT NULL,
			gid              INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN,
			FOREIGN KEY (gid) REFERENCES groups(id),
			FOREIGN KEY (uid) REFERENCES users(id)
);

CREATE TABLE subscriptions_all (
			id               INTEGER PRIMARY KEY DEFAULT nextval('subscriptions_all_id_seq'::regclass),
			uid              INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN,
			FOREIGN KEY (uid) REFERENCES users(id)
);

CREATE TABLE subscriptions_pauseid (
			id               INTEGER PRIMARY KEY DEFAULT nextval('subscriptions_pauseid_id_seq'::regclass),
			uid              INTEGER NOT NULL,
			pauseid          INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN,
			FOREIGN KEY (pauseid) REFERENCES authors(id),
			FOREIGN KEY (uid) REFERENCES users(id)
);

CREATE UNIQUE INDEX groups_name ON groups (name);
CREATE INDEX posts_thread ON posts (thread);
CREATE INDEX posts_gid ON posts (gid);
CREATE INDEX posts_uid ON posts (uid);

---- add tagcloud
--- TODO unique tag_id, group_id pair
CREATE TABLE tags (
			id               INTEGER PRIMARY KEY DEFAULT nextval('tags_id_seq'::regclass),
			name             VARCHAR(100) UNIQUE NOT NULL
);
CREATE UNIQUE INDEX tags_name ON tags (name);
CREATE TABLE tag_cloud (
			uid              INTEGER,
			tag_id           INTEGER,
			group_id         INTEGER,
			stamp            TEXT,
			FOREIGN KEY (uid) REFERENCES users(id),
			FOREIGN KEY (tag_id) REFERENCES tags(id),
			FOREIGN KEY (group_id) REFERENCES groups(id)
);
CREATE INDEX tags_cloud_uid ON tag_cloud (uid);
CREATE INDEX tags_cloud_tag_id ON tag_cloud (tag_id);
CREATE INDEX tags_cloud_group_id ON tag_cloud (group_id);


