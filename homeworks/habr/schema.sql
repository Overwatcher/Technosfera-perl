["CREATE TABLE user(
nick varchar(256) NOT NULL PRIMARY KEY,
karma double,
rating double);",
"CREATE TABLE post(
id integer NOT NULL PRIMARY KEY,
author varchar(256),
title varchar(256),
rating integer,
stars integer,
views integer,
comments_count integer,
FOREIGN KEY(author) REFERENCES user(nick));",
"CREATE TABLE commenters(
autoid integer PRIMARY KEY AUTOINCREMENT,
user text,
postid integer,
FOREIGN KEY(user) REFERENCES user(nick),
FOREIGN KEY(postid) REFERENCES post(id));"]

