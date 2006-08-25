CREATE TABLE users (
			id               INTEGER PRIMARY KEY auto_increment,
			username         VARCHAR(255) UNIQUE,
			password         VARCHAR(255),
			email            VARCHAR(255) UNIQUE,
			fname            VARCHAR(255),
			lname            VARCHAR(255),
			update_on_new_user VARCHAR(1),
			status           INTEGER
-- registration_date
-- last_seen
-- locaton
-- user_localtime
-- scratch_pad

);

CREATE TABLE usergroups (
			id               INTEGER PRIMARY KEY auto_increment,
			name             VARCHAR(255) UNIQUE
);

CREATE TABLE user_in_group (
			uid               INTEGER,
			gid               INTEGER
);

CREATE TABLE configure (
			field             VARCHAR(255),
			value             VARCHAR(255)
);


--CREATE TABLE grouptypes (
--			id               INTEGER PRIMARY KEY auto_increment,
--			name             VARCHAR(255) NOT NULL
--);
-- grouptypes can be   Global/Distribution/Field



CREATE TABLE groups (
			id               INTEGER PRIMARY KEY auto_increment,
			name             VARCHAR(255) UNIQUE NOT NULL,
			status           INTEGER,
			gtype            INTEGER NOT NULL,
			version          VARCHAR(100),
			pauseid          INTEGER,
			rating           VARCHAR(10),	
			review_count     INTEGER
			,FOREIGN KEY (pauseid)  REFERENCES authors(id)
);

CREATE TABLE metagroups (
			id               INTEGER PRIMARY KEY auto_increment,
			name             VARCHAR(255) UNIQUE NOT NULL,
			status           INTEGER
);

CREATE TABLE group_in_meta (
			mgid             INTEGER NOT NULL,
			gid              INTEGER NOT NULL
			,FOREIGN KEY (mgid)  REFERENCES metagroups(id)
			,FOREIGN KEY (gid)   REFERENCES groups(id)
);

	

CREATE TABLE grouprelations (
			parent            INTEGER NOT NULL,
			child            INTEGER NOT NULL
			,FOREIGN KEY (parent) REFERENCES groups(id)
			,FOREIGN KEY (child) REFERENCES groups(id)
);

-- grouprelations defined which group belongs to which other group, 
-- In the application level we'll have to implement the restriction so 
-- Global group will have no parent
-- Fields will have Global as parent
-- Distributions will have Fields as parent one child can have several parents
-- Modules (if added) will have Distributions as parents


CREATE TABLE posts (
			id               INTEGER PRIMARY KEY auto_increment,
			gid              INTEGER NOT NULL,
			uid              INTEGER NOT NULL,
			parent           INTEGER,
			thread           INTEGER,
			hidden           BOOLEAN,
			subject          VARCHAR(255) NOT NULL,
			text             VARCHAR(100000) NOT NULL,
			date             TIMESTAMP
			,FOREIGN KEY (gid) REFERENCES groups(id)
			,FOREIGN KEY (uid) REFERENCES users(id)
			,FOREIGN KEY (parent) REFERENCES posts(id)
);

CREATE TABLE authors (
			id               INTEGER PRIMARY KEY auto_increment,
			pauseid          VARCHAR(100) UNIQUE NOT NULL
);


CREATE TABLE subscriptions (
			id               INTEGER PRIMARY KEY auto_increment,
			uid              INTEGER NOT NULL,
			gid              INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN
			,FOREIGN KEY (gid) REFERENCES groups(id)
			,FOREIGN KEY (uid) REFERENCES users(id)
);

CREATE TABLE subscriptions_all (
			id               INTEGER PRIMARY KEY auto_increment,
			uid              INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN
			,FOREIGN KEY (uid) REFERENCES users(id)
);

CREATE TABLE subscriptions_pauseid (
			id               INTEGER PRIMARY KEY auto_increment,
			uid              INTEGER NOT NULL,
			pauseid          INTEGER NOT NULL,
			allposts         BOOLEAN,
			starters         BOOLEAN,
			followups        BOOLEAN,
			announcements    BOOLEAN
			,FOREIGN KEY (pauseid) REFERENCES authors(id)
			,FOREIGN KEY (uid) REFERENCES users(id)
);

CREATE TABLE sessions (
    id               CHAR(32) NOT NULL UNIQUE,
    a_session        TEXT NOT NULL,
    uid              INTEGER
);



