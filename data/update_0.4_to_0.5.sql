CREATE TABLE "bonus_points" (
  "bonus" text NOT NULL,
  "uid" integer NOT NULL,
  "points" integer NOT NULL,
  PRIMARY KEY ("bonus", "uid"),
  FOREIGN KEY ("uid") REFERENCES "users" ("uid")
);
