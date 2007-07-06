
---- add tagcloud
--- TODO unique tag_id, group_id pair
CREATE TABLE tags (
			id               INTEGER PRIMARY KEY,
			name             VARCHAR(100) UNIQUE NOT NULL
);
CREATE UNIQUE INDEX tags_name ON tags (name);
CREATE TABLE tag_cloud (
			uid              INTEGER,
			tag_id           INTEGER,
            group_id         INTEGER
			,FOREIGN KEY (uid) REFERENCES users(id)
			,FOREIGN KEY (tag_id) REFERENCES tags(id)
			,FOREIGN KEY (group_id) REFERENCES groups(id)
);
CREATE INDEX tags_cloud_uid ON tag_cloud (uid);
CREATE INDEX tags_cloud_tag_id ON tag_cloud (tag_id);
CREATE INDEX tags_cloud_group_id ON tag_cloud (group_id);

ALTER TABLE tag_cloud ADD stamp TEXT;
