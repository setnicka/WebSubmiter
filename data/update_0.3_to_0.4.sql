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
