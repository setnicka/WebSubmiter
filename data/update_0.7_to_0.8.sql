CREATE TABLE "comments_viewed" (
  "uid" integer NOT NULL,
  "sid" integer NOT NULL,
  "cid" integer NOT NULL,
  FOREIGN KEY ("uid") REFERENCES "users" ("uid"),
  FOREIGN KEY ("sid") REFERENCES "solutions" ("sid"),
  FOREIGN KEY ("cid") REFERENCES "comments" ("cid")
);

CREATE UNIQUE INDEX "comments_viewed_uid_sid" ON "comments_viewed" ("uid", "sid");
