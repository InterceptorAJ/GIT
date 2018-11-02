CREATE DIRECTORY MEDIA_FILES AS '/home/oracle/MEDIA_FILES';
commit;

CREATE DIRECTORY export_dir AS '/home/oracle/export';
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


CREATE OR REPLACE PROCEDURE EXPORT_MEAL_IMAGES (
  recipe MEAL_IMAGES.recipe_id%TYPE
) IS
    CURSOR images IS
      SELECT image, name
        FROM MEAL_IMAGES WHERE recipe_id = recipe;
  image_row images%ROWTYPE;
  image ORDSYS.ORDIMAGE;
  ctx raw(64) := null;
  has_element boolean := false;
BEGIN
  OPEN images;
    LOOP
      FETCH images INTO image_row;
      EXIT WHEN images%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE(recipe);
      has_element := true;
      image := image_row.image;
      image.export(ctx, 'FILE', 'EXPORT_DIR', 'export_' || image_row.name);
    END LOOP;
  CLOSE images;
  IF has_element then
    DBMS_OUTPUT.PUT_LINE('Zdjecie zostalo wyeksportowane');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Podany przepis nie istnieje');
  END IF;
END;

EXECUTE EXPORT_MEAL_IMAGES(1);


CREATE OR REPLACE PROCEDURE ADD_INGREDIENT (
    name INGREDIENTS.name%TYPE,
    file_name VARCHAR2
  )
  IS
    img ORDImage;
    ctx RAW(64) := NULL;
    row_id urowid;
    metav XMLSequenceType;
    meta_root VARCHAR2(40);
    xmlORD XMLType;
    xmlXMP XMLType;
    img_tags VARCHAR2(4000);
    format  VARCHAR2(200);
  BEGIN
    INSERT INTO ingredients (name, image)
    VALUES (name, ORDImage.init('FILE', 'MEDIA_FILES', file_name))
    RETURNING image, rowid INTO img, row_id;
    img.import(ctx);
    UPDATE ingredients SET image = img WHERE rowid = row_id;
    COMMIT;
    
    metav := img.getMetadata( 'ALL' );
    format := img.getFileFormat();
    
 
    FOR i IN 1..metav.count() LOOP
      meta_root := metav(i).getRootElement();
      CASE meta_root
        WHEN 'ordImageAttributes' THEN xmlORD := metav(i);
        WHEN 'xmpMetadata' THEN xmlXMP := metav(i);
        ELSE NULL;
      END CASE;
    END LOOP;

    UPDATE ingredients 
    SET metaORDImage = xmlORD,
        metaXMP = xmlXMP
    WHERE rowid = row_id;    
    
        UPDATE ingredients 
    SET metaORDImage = xmlORD,
        metaXMP = xmlXMP
    WHERE rowid = row_id;    
    
    SELECT 
      extract(metaXMP, '/xmpMetadata/*[0]/*[0]/*[0]/*[0]/*[0]/text()', 'xmlns="http://xmlns.oracle.com/ord/meta/xmp"').getStringVal()
      INTO img_tags
      from ingredients 
      WHERE rowid = row_id;
      
    
    UPDATE ingredients 
    SET tags = img_tags, fileFormat = format 
    WHERE rowid = row_id;    
    COMMIT;

        
    DBMS_OUTPUT.PUT_LINE('Skladnik zostal dodany pomyslnie');
END;


EXECUTE add_ingredient('name', 'banan.jpg');

SELECT id, name from ingredients WHERE tags like '%banan%';


CREATE OR REPLACE PROCEDURE ADD_RECIPE_ING (
    rec_id INGREDIENTS_RECIPES.recipe_id%TYPE,
    ing_id INGREDIENTS_RECIPES.ingridient_id%TYPE,
    qua INGREDIENTS_RECIPES.quantity%TYPE
  )
  IS
    AUTHOR_NOT_FOUND exception;
    PRAGMA EXCEPTION_INIT(AUTHOR_NOT_FOUND, -2291);
  BEGIN
    INSERT INTO RECIPES (recipe_id, ingridient_id, quantity)
      VALUES (rec_id, ing_id, qua);
    COMMIT ;
    DBMS_OUTPUT.PUT_LINE('Skladnik zostal przypisany do przepisu pomyslnie');
    EXCEPTION
    WHEN AUTHOR_NOT_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Podany autor nie istnieje (id:)');
END;


CREATE OR REPLACE PROCEDURE ADD_RECIPE_ING (
    rec_id INGREDIENTS_RECIPES.recipe_id%TYPE,
    ingr_id INGREDIENTS_RECIPES.ingredient_id%TYPE,
    quantity INGREDIENTS_RECIPES.quantity%TYPE
  )
  IS
    recipe_count NUMBER;
    ingr_count NUMBER;
    ALREADY_EXISTS exception;
    PRAGMA EXCEPTION_INIT(ALREADY_EXISTS, -1);
  BEGIN
    SELECT count(*) INTO recipe_count FROM recipes WHERE id = rec_id;
    SELECT count(*) INTO ingr_count FROM ingredients WHERE id = ingr_id;
    IF recipe_count = 0 THEN
      DBMS_OUTPUT.PUT_LINE('Podany przepis nie istnieje');
    ELSIF ingr_count = 0 THEN
      DBMS_OUTPUT.PUT_LINE('Podany skladnik nie istnieje');
    ELSIF quantity <= 0 THEN
      DBMS_OUTPUT.PUT_LINE('Ilosc musi byc dodatnia');
    ELSE
      INSERT INTO INGREDIENTS_RECIPES (recipe_id, ingredient_id, quantity)
        VALUES (rec_id, ingr_id, quantity);
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('Skladnik zostal przypisany do przepisu pomyslnie');
    END IF;
    EXCEPTION
      WHEN ALREADY_EXISTS THEN
        UPDATE INGREDIENTS_RECIPES SET quantity = quantity;
        DBMS_OUTPUT.PUT_LINE('Ilosc skladnika zostala zaktualizana');

END;

EXECUTE add_recipe_ing(1,1,1)

CREATE OR REPLACE PROCEDURE INGREDIENT_TO_PNG (
  ing_id INGREDIENTS.id%TYPE,
  new_name VARCHAR2
) IS
  obr1 ORDimage;
  ctx raw(64) :=null;
BEGIN
    SELECT image INTO obr1 FROM ingredients
    WHERE id=ing_id FOR UPDATE of image;

    obr1.process('fileFormat=PNGF');
    UPDATE ingredients set image = obr1 WHERE id=1;
    COMMIT;
    obr1.export(ctx, 'FILE', 'EXPORT_DIR', new_name || '.png');
    DBMS_OUTPUT.PUT_LINE('Zdjecie zostalo przekonwertowane do formatu png');
END;


CREATE OR REPLACE PROCEDURE SCALE_INGREDIENT (
  ing_id INGREDIENTS.id%TYPE,
  new_name VARCHAR2,
  xScale float,
  yScale float
) IS
  obr1 ORDimage;
  ctx raw(64) :=null;
BEGIN
    SELECT image INTO obr1 FROM ingredients
    WHERE id=ing_id FOR UPDATE of image;
    obr1.process('xScale=' || xScale);
    obr1.process('yScale=' || yScale);

    obr1.export(ctx, 'FILE', 'EXPORT_DIR', new_name || '.png');
    DBMS_OUTPUT.PUT_LINE('Zdjecie zostalo przeskalowane poprawnie');
END;

