-- TABLE DROPING
--DROP TABLE ingredients_recipes;
--DROP TABLE ingredients;
--DROP TABLE meal_images;
--DROP TABLE recipes;
--DROP TABLE authors;


-- TABLE DROPING


CREATE TABLE authors (
  id NUMBER PRIMARY KEY,
  first_name VARCHAR2(32) NOT NULL,
  last_name VARCHAR2(32) NOT NULL,
  email VARCHAR2(50) NOT NULL,
  phone_no VARCHAR2(10)
);

CREATE UNIQUE INDEX unique_email ON AUTHORS(email);

DROP SEQUENCE authors_seq
CREATE SEQUENCE authors_seq START WITH 1;

-- set autoincrement id on create
CREATE OR REPLACE TRIGGER author_id
BEFORE INSERT ON authors
FOR EACH ROW
BEGIN
  SELECT authors_seq.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;


CREATE TABLE recipes (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50) NOT NULL,
  description VARCHAR2(20),
  author_id NUMBER NOT NULL,
  CONSTRAINT recipe_author_fk FOREIGN KEY(author_id) REFERENCES authors(id)
);

DROP SEQUENCE recipes_seq;
CREATE SEQUENCE recipes_seq START WITH 1;

-- set autoincrement id on create
CREATE OR REPLACE TRIGGER recipes_id
BEFORE INSERT ON recipes
FOR EACH ROW

BEGIN
  SELECT recipes_seq.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;


CREATE TABLE meal_images (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50),
  image ORDIMAGE NOT NULL,
  recipe_id NUMBER NOT NULL,
  CONSTRAINT meal_image_recipe_fk FOREIGN KEY(recipe_id) REFERENCES recipes(id)
);

DROP SEQUENCE meal_images_seq;
CREATE SEQUENCE meal_images_seq START WITH 1;

-- set autoincrement id on create
CREATE OR REPLACE TRIGGER meal_image_id
BEFORE INSERT ON meal_images
FOR EACH ROW

BEGIN
  SELECT meal_images_seq.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;



CREATE TABLE ingredients (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50) NOT NULL,
  image ORDIMAGE,
  image_signature ORDSYS.ORDImageSignature,  -- potrzebne do porównywania obrazów
  metaORDImage XMLTYPE,
  metaXMP      XMLTYPE,
  tags VARCHAR2(4000)
);

DROP SEQUENCE ingredients_seq;
CREATE SEQUENCE ingredients_seq START WITH 1;

-- set autoincrement id on create
CREATE OR REPLACE TRIGGER ingredient_id
BEFORE INSERT ON ingredients
FOR EACH ROW

BEGIN
  SELECT ingredients_seq.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;


CREATE TABLE ingredients_recipes (
  recipe_id NUMBER NOT NULL,
  ingredient_id NUMBER NOT NULL,
  quantity NUMBER DEFAULT 1,
  CONSTRAINT recipe_mtm_fk FOREIGN KEY(recipe_id) REFERENCES recipes(id),
  CONSTRAINT ingredient_mtm_fk FOREIGN KEY(ingredient_id) REFERENCES ingredients(id),
  CONSTRAINT ingredients_recipes_pk PRIMARY KEY (recipe_id, ingredient_id)
);
