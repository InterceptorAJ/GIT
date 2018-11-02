-- TABLE DROPING
--DROP TABLE ingredients_recipes;
--DROP TABLE ingredients;
--DROP TABLE recipes;
--DROP TABLE authors;


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

CREATE OR REPLACE TRIGGER recipe_code
BEFORE INSERT ON recipes
FOR EACH ROW
DECLARE 
  fname VARCHAR2(30);
  temp NUMBER;
    
BEGIN
  SELECT first_name
    INTO   fname
    FROM   authors
    WHERE id = :new.author_id;
  SELECT count(*) INTO temp FROM recipes WHERE recipe_code LIKE fname || '-%';
  SELECT fname || '-' || (temp + 1)
    INTO :new.recipe_code
    FROM dual; 
END;



CREATE TABLE ingredients (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(50) NOT NULL,
  image ORDIMAGE,
  image_signature ORDSYS.ORDImageSignature,  -- potrzebne do porównywania obrazów
  metaORDImage XMLTYPE,
  metaXMP      XMLTYPE,
  tags VARCHAR2(4000),
  fileFormat VARCHAR2(200)
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

CREATE OR REPLACE PROCEDURE EXPORT_INGREDIETNS
IS
	CURSOR images IS
	  SELECT image, name
		FROM INGREDIENTS;
	image_row images%ROWTYPE;
	image ORDSYS.ORDIMAGE;
	ctx raw(64) := null;
	has_element boolean := false;
BEGIN
  OPEN images;
    LOOP
      FETCH images INTO image_row;
      EXIT WHEN images%NOTFOUND;
      has_element := true;
      image := image_row.image;
      image.export(ctx, 'FILE', 'EXPORT_DIR', 'export_' || image_row.name);
    END LOOP;
  CLOSE images;
  IF has_element then
    DBMS_OUTPUT.PUT_LINE('Zdjecia zostaly wyeksportowane');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Nie ma dodanych skladnikow');
  END IF;
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
