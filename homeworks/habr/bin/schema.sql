["CREATE TABLE user(
nick varchar(256) NOT NULL PRIMARY KEY,
karma double,
rating double);","CREATE TABLE post(
id integer NOT NULL PRIMARY KEY,
author varchar(256),
title varchar(256),
rating integer,
stars integer,
views integer,
commenters text,
comm_number integer,
FOREIGN KEY(author) REFERENCES user(nick));"]

