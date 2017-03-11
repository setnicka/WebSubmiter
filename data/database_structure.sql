CREATE TABLE "users" (
  "uid" integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  "login" text NOT NULL,
  "passwd" text NOT NULL,
  "salt" text NOT NULL,
  "name" text NOT NULL,
  "nick" text NOT NULL,
  "email" text NOT NULL
);

CREATE TABLE "solutions" (
  "sid" integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  "task" text NOT NULL,
  "uid" integer NOT NULL,
  "date" integer NOT NULL,
  "code" text NOT NULL,
  "points" integer NOT NULL DEFAULT '0',
  "rated" integer NOT NULL DEFAULT '0',
  FOREIGN KEY ("uid") REFERENCES "users" ("uid")
);

CREATE TABLE "comments" (
  "cid" integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  "sid" integer NOT NULL,
  "uid" integer NOT NULL,
  "date" integer NOT NULL,
  "teacher" integer NOT NULL,
  "text" text NOT NULL,
  "html" text NOT NULL,
  FOREIGN KEY ("sid") REFERENCES "solutions" ("sid"),
  FOREIGN KEY ("uid") REFERENCES "users" ("uid")
);

CREATE TABLE "notifications" (
  "nid" integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  "type" text NOT NULL,
  "uid" integer NOT NULL,
  "sid" integer NOT NULL,
  "cid" integer NOT NULL,
  "text" text NOT NULL,
  "sended" integer NOT NULL DEFAULT '0',
  FOREIGN KEY ("uid") REFERENCES "users" ("uid"),
  FOREIGN KEY ("sid") REFERENCES "solutions" ("sid"),
  FOREIGN KEY ("cid") REFERENCES "comments" ("cid")
);

CREATE TABLE sqlite_sequence(name,seq);
