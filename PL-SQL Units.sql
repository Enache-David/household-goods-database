create or replace procedure procedura_ex_6
as
    type t_tablou_comenzi is table of
        comenzi.id_comanda%type
        index by pls_integer;
    type t_record_produse is record
        (id_produs produse.id_produs%type,
         nume produse.nume%type,
         pret produse.pret%type);
    type t_tablou_produse is table of
        t_record_produse;
    type t_vector_categorii is varray (5) of
        categorii.nume%type;

    cursor cursor_categorii(p_id_produs produse.id_produs%type) is
        select c.nume
        from categorii c
        join lk_categorii_produse cp on c.id_categorie = cp.categorie_id
        where cp.produs_id = p_id_produs;

    v_tablou_comenzi t_tablou_comenzi;
    v_tablou_produse t_tablou_produse := t_tablou_produse();
    v_vector_categorii t_vector_categorii := t_vector_categorii();
    v_index number(1);
begin
    for i in 1..5 loop
        v_vector_categorii.extend;
        end loop;

    select id_comanda
    bulk collect into v_tablou_comenzi
    from comenzi;

    for i in v_tablou_comenzi.first..v_tablou_comenzi.last loop
        dbms_output.PUT_LINE('ID Comandă: ' || v_tablou_comenzi(i));
        dbms_output.PUT_LINE('--------------------');

        select p.id_produs, p.nume, p.pret
        bulk collect into v_tablou_produse
        from produse p
        join lk_utilizatori_comenzi_produse ucp on p.id_produs = ucp.produs_id
        where ucp.comanda_id = v_tablou_comenzi(i);

        for j in v_tablou_produse.first..v_tablou_produse.last loop
            dbms_output.PUT(v_tablou_produse(j).nume || ', ' || v_tablou_produse(j).pret || ' lei');
            open cursor_categorii(v_tablou_produse(j).id_produs);
            v_index := 1;

            loop
                fetch cursor_categorii into v_vector_categorii(v_index);
                exit when cursor_categorii%notfound;
                v_index := v_index + 1;
            end loop;

            for k in v_vector_categorii.first..v_index-1 loop
                dbms_output.PUT(', ' || v_vector_categorii(k));
                end loop;

            dbms_output.PUT_LINE(' ');
            close cursor_categorii;
        end loop;
        dbms_output.PUT_LINE(' ');
        end loop;
end;

begin
    procedura_ex_6();
end;

create or replace procedure procedura_ex_7
as
    cursor cursor_utilizatori(p_oras_id orase.id_oras%type)
    is
        select nume, prenume
        from utilizatori
        where oras_id = p_oras_id;
    v_nume_utilizator utilizatori.nume%type;
    v_prenume_utilizator utilizatori.prenume%type;
begin
    for v_oras in (
        select id_oras, nume
        from orase
        ) loop
        dbms_output.PUT_LINE(v_oras.nume);
        dbms_output.PUT_LINE('--------------------');
        open cursor_utilizatori(v_oras.id_oras);
        loop
            fetch cursor_utilizatori into v_nume_utilizator, v_prenume_utilizator;
            exit when cursor_utilizatori%notfound;
            dbms_output.PUT_LINE(v_nume_utilizator || ' ' || v_prenume_utilizator);
        end loop;
        close cursor_utilizatori;
        dbms_output.PUT_LINE(' ');
        end loop;
end;

begin
    procedura_ex_7();
end;

create or replace function functie_ex_8(
    p_categorie categorii.nume%type,
    p_culoare culori.nume%type
)
return produse%rowtype
as
    exceptie_prea_multe_produse exception;
    pragma exception_init (exceptie_prea_multe_produse, -01422);
    v_produs produse%rowtype;
begin
    select p.*
    into v_produs
    from produse p
    join culori cul on p.culoare_id = cul.id_culoare
    join lk_categorii_produse cp on p.id_produs = cp.produs_id
    join categorii c on cp.categorie_id = c.id_categorie
    where upper(c.nume) = upper(p_categorie) and
          upper(cul.nume) = upper(p_culoare) and
          p.pret = (
                    select max(p.pret)
                    from produse p
                    join culori cul on p.culoare_id = cul.id_culoare
                    join lk_categorii_produse cp on p.id_produs = cp.produs_id
                    join categorii c on cp.categorie_id = c.id_categorie
                    where upper(c.nume) = upper(p_categorie) and
                          upper(cul.nume) = upper(p_culoare)
              );

    return v_produs;
end;

declare
    v_produs produse%rowtype;
begin
    v_produs := functie_ex_8('mobilier', 'alb');
    dbms_output.PUT_LINE(v_produs.nume || ', ' || v_produs.pret || ' lei');
    dbms_output.PUT_LINE(v_produs.descriere);
    dbms_output.PUT_LINE(' ');

    begin
        v_produs := functie_ex_8('corpuri de iluminat', 'negru');
        dbms_output.PUT_LINE(v_produs.nume || ', ' || v_produs.pret || ' lei');
        dbms_output.PUT_LINE(v_produs.descriere);
    exception
        when no_data_found then
            dbms_output.PUT_LINE('Nu există produse care corespund căutării.');
            dbms_output.PUT_LINE(' ');
    end;

    begin
        v_produs := functie_ex_8('corpuri de iluminat', 'alb');
        dbms_output.PUT_LINE(v_produs.nume || ', ' || v_produs.pret || ' lei');
        dbms_output.PUT_LINE(v_produs.descriere);
    exception
        when too_many_rows then
            dbms_output.PUT_LINE('Există mai multe produse care corespund căutării.');
            dbms_output.PUT_LINE(' ');
    end;
end;

create or replace procedure procedura_ex_9(
    p_total number,
    p_oras orase.nume%type
)
as
    cursor cursor_comenzi is
        select u.nume, u.prenume, c.id_comanda, sum(p.pret * ucp.cantitate) total, o.nume
        from utilizatori u
        join lk_utilizatori_comenzi_produse ucp on u.id_utilizator = ucp.utilizator_id
        join comenzi c on ucp.comanda_id = c.id_comanda
        join destinatii_ridicare dr on c.destinatie_id = dr.id_destinatie
        join orase o on dr.oras_id = o.id_oras
        join produse p on ucp.produs_id = p.id_produs
        group by u.nume, u.prenume, c.id_comanda, o.nume;

    v_nume_utilizator utilizatori.nume%type;
    v_prenume_utilizator utilizatori.prenume%type;
    v_id_comanda comenzi.id_comanda%type;
    v_total number(5);
    v_oras orase.nume%type;
    v_gasit_total number(1);
    v_gasit_oras number(1);
    v_gasit number(1);

    nu_exista_total_oras exception;
    nu_exista_total exception;
    nu_exista_oras exception;
    nu_exista_comanda exception;
begin
    v_gasit_total := 0;
    v_gasit_oras := 0;
    v_gasit := 0;
    open cursor_comenzi;
    loop
        fetch cursor_comenzi into v_nume_utilizator, v_prenume_utilizator, v_id_comanda, v_total, v_oras;
        exit when cursor_comenzi%notfound;

        if v_total <= p_total and upper(v_oras) = upper(p_oras) then
            dbms_output.PUT_LINE('ID Comandă: ' || v_id_comanda || ', Total: ' || v_total || ' lei, ' || v_nume_utilizator || ' ' || v_prenume_utilizator);
            v_gasit := 1;
        end if;

        if v_total <= p_total then
            v_gasit_total := 1;
        end if;

        if upper(v_oras) = upper(p_oras) then
            v_gasit_oras := 1;
        end if;
    end loop;
    close cursor_comenzi;

    if v_gasit_total = 0 and v_gasit_oras = 0 then
        raise nu_exista_total_oras;

    elsif v_gasit_total = 0 then
        raise nu_exista_total;

    elsif v_gasit_oras = 0 then
        raise nu_exista_oras;

    elsif v_gasit = 0 then
        raise nu_exista_comanda;
    end if;

    dbms_output.PUT_LINE(' ');
exception
    when nu_exista_total_oras then
        dbms_output.PUT_LINE('Nu există nicio comandă cu totalul mai mic sau egal cu ' || p_total || ' lei și nu există nicio comandă a cărei destinație de ridicare se află în orașul ' || upper(p_oras) || '. Dacă este cazul, asigurați-vă că numele orașului a fost introdus folosind diacritice.');
        dbms_output.PUT_LINE(' ');
    when nu_exista_total then
        dbms_output.PUT_LINE('Nu există nicio comandă cu totalul mai mic sau egal cu ' || p_total || ' lei.');
        dbms_output.PUT_LINE(' ');
    when nu_exista_oras then
        dbms_output.PUT_LINE('Nu există nicio comandă a cărei destinație de ridicare se află în orașul ' || upper(p_oras) || '. Dacă este cazul, asigurați-vă că numele orașului a fost introdus folosind diacritice.');
        dbms_output.PUT_LINE(' ');
    when nu_exista_comanda then
            dbms_output.PUT_LINE('Nu există nicio comandă care îndeplinește ambele condiții (Total <= ' || p_total || ' lei, Orașul destinației de ridicare: ' || upper(p_oras) || ').');
            dbms_output.PUT_LINE(' ');
end;

begin
    procedura_ex_9(5000, 'bucurești');

    procedura_ex_9(500, 'craiova');

    procedura_ex_9(500, 'bucurești');

    procedura_ex_9(5000, 'craiova');

    procedura_ex_9(1000, 'bucurești');
end;

create or replace trigger trigger_ex_10
before delete or update on comenzi
    begin
        raise_application_error(-20001, 'Comenzile nu pot fi șterse sau actualizate.');
    end;

update comenzi
set finalizata = 1
where id_comanda = 5;

create or replace trigger trigger_ex_11
before update of pret on produse
for each row
when (
        new.pret < 0.5 * old.pret
    )
    begin
        raise_application_error(-20002, 'Prețul unui produs nu poate fi micșorat cu mai mult de 50%.');
    end;

update produse
set pret = 49.90
where id_produs = 6;

create or replace trigger trigger_ex_12
before drop on database
    when (
            sys.DICTIONARY_OBJ_NAME() = 'PRODUSE'
        )
    begin
        raise_application_error(-20003, 'Tabelul PRODUSE nu poate fi șters.');
    end;

drop table produse;

alter trigger trigger_ex_12 disable;
alter trigger trigger_ex_12 enable;