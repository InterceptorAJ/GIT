-- TABLE DROPING
--DROP TABLE ingredients_recipes;
--DROP TABLE ingredients;
--DROP TABLE meal_images;
--DROP TABLE recipes;
--DROP TABLE authors;


CREATE TABLE authors (
  id NUMBER PRIMARY KEY,
  first_name VARCHAR2(32) NOT NULL,
  last_name VARCHAR(32) NOT NULL,
  email VARCHAR(50) NOT NULL,
  phone_no VARCHAR(10)
);

CREATE TABLE recipes (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50) NOT NULL,
  description VARCHAR2(20),
  author_id NUMBER NOT NULL,
  CONSTRAINT recipe_author_fk FOREIGN KEY(author_id) REFERENCES authors(id)
);

CREATE TABLE meal_images (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50),
  image ORDIMAGE NOT NULL,
  recipe_id NUMBER NOT NULL,
  CONSTRAINT meal_image_recipe_fk FOREIGN KEY(recipe_id) REFERENCES recipes(id)
);

CREATE TABLE ingredients (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50) NOT NULL,
  image ORDIMAGE NOT NULL
);

CREATE TABLE ingredients_recipes (
  recipe_id NUMBER NOT NULL,
  ingridient_id NUMBER NOT NULL,
  CONSTRAINT recipe_mtm_fk FOREIGN KEY(recipe_id) REFERENCES recipes(id),
  CONSTRAINT ingidient_mtm_fk FOREIGN KEY(ingridient_id) REFERENCES ingredients(id),
  CONSTRAINT ingredients_recipes_pk PRIMARY KEY (recipe_id, ingridient_id)
);
