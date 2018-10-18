CREATE DIRECTORY MEDIA_FILES AS '/home/oracle/MEDIA_FILES';
commit;

-- use this to enable dbms logs
SET serveroutput ON SIZE 1000000


--
-- AUTHORS
--

CREATE OR REPLACE PROCEDURE ADD_AUTHOR (
    first_name AUTHORS.first_name%TYPE,
    last_name AUTHORS.last_name%TYPE,
    email AUTHORS.email%TYPE,
    phone_no AUTHORS.phone_no%TYPE
  )
  AS BEGIN
    INSERT INTO AUTHORS (first_name, last_name, email, phone_no)
      VALUES (first_name, last_name, email, phone_no);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Autor zosta dodany pomyslnie');

  EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('Autor z adresem email: ' || email|| ' juz istnieje');
END;

EXECUTE ADD_AUTHOR('rafal', 'kowalski', 'mail@mail2.com', '123232')


--
-- RECIPES
--

CREATE OR REPLACE PROCEDURE ADD_RECIPE (
    name RECIPES.name%TYPE,
    description RECIPES.description%TYPE,
    author_id RECIPES.author_id%TYPE
  )
  IS
    -- When foreign key does not exist 02291 error is raise.
    AUTHOR_NOT_FOUND exception;
    PRAGMA EXCEPTION_INIT(AUTHOR_NOT_FOUND, -2291);
  BEGIN
    INSERT INTO RECIPES (name, description, author_id) 
      VALUES (name, description, author_id);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Przepis zosta dodany pomyslnie');
    EXCEPTION
    WHEN AUTHOR_NOT_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Podany autor nie istnieje (id:' || author_id || ')');
END;

EXECUTE ADD_RECIPE('name', 'desd', 1)


--
-- RECIPES IMAGES
--

CREATE OR REPLACE PROCEDURE ADD_RECIPE_IMAGE (
    recipe_id MEAL_IMAGES.recipe_id%TYPE,
    file_name VARCHAR2
  )
  IS
    image ORDImage;
    ctx RAW(64) := NULL;
    row_id urowid;
  BEGIN
    INSERT INTO MEAL_IMAGES (name, recipe_id, image)
      VALUES (file_name, recipe_id, ORDImage.init('FILE', 'MEDIA_FILES', file_name))
      RETURNING image, rowid INTO image, row_id;
      image.import(ctx);
      UPDATE meal_images SET image = image WHERE row_id = row_id;
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('Zdjecie zostalo dodane pomyslnie');
END;

EXECUTE ADD_RECIPE_IMAGE(1, 'banan.jpg')