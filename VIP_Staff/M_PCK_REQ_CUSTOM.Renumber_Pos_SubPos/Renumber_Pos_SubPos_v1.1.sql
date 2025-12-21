--- M_PCK_REQ_CUSTOM
v_pd_zr_rliinc     NUMBER;

  /* collect DISTINCT part_id and commodity_code from  new (pos<0)  m_req line items */
  CURSOR commodity_code_cur IS
      SELECT DISTINCT cc.commodity_id, cc.part_id, cc.commodity_code 
        FROM m_req_line_items rli,m_idents i,m_commodity_codes cc  
       WHERE i.ident = rli.ident
         and cc.commodity_id = i.commodity_id
         and rli.r_id = p_r_id
         --And rli.last_rli_id is null 
         and rli.rli_pos < 0
         and rli.manual_ind = 'N'
       ORDER BY cc.part_id, cc.commodity_code;

  /* manual line items */
  CURSOR rli_man_cur IS
      SELECT rli.rli_id, rli.rli_pos
        FROM m_req_line_items rli,
             mvp_idents i,
             mvp_commodity_codes cc
       WHERE rli.r_id = p_r_id
         AND rli.manual_ind = 'Y'
         AND rli.last_rli_id IS NULL
         AND i.ident = rli.ident
         AND cc.commodity_id = i.commodity_id
       ORDER BY cc.commodity_code, i.input_1, i.input_2;

   commodity_code_rec           commodity_code_cur%ROWTYPE;

   /* collect new (pos<0) req line items with pos or sub > 1) */
   CURSOR rli_cur IS
      SELECT  rli.rli_id, rli.last_rli_id
        FROM m_req_line_items rli,m_idents i  
       WHERE i.ident = rli.ident
         and  i.commodity_id = commodity_code_rec.commodity_id
         and rli.r_id = p_r_id
         --And rli.last_rli_id is null 
         and rli.rli_pos < 0
         and rli.manual_ind = 'N'
       ORDER BY to_number(i.input_1), to_number(i.input_2);

   rli_rec       rli_cur%ROWTYPE;
   
   max_pos           NUMBER := 0;
   new_pos           NUMBER := 0;
   new_sub_pos       NUMBER := 0;

----------------------------------------------------------------------------------------------------

  SELECT NVL(TO_NUMBER(m_pck_ppd_defaults.get_value('ZR_RLIINC')),1)
  INTO v_pd_zr_rliinc
  FROM dual;

--update all new req line item position to negative
  UPDATE m_req_line_items
     SET rli_pos = - rli_pos,
         rli_sub_pos = - rli_sub_pos
--fetch all new req_line_item
   WHERE r_id = p_r_id
     AND last_rli_id IS NULL;

  

  IF NOT commodity_code_cur%ISOPEN THEN
    OPEN commodity_code_cur;
  END IF;

  FETCH commodity_code_cur INTO commodity_code_rec;

  /* MTO line items */
  WHILE commodity_code_cur%FOUND LOOP
	-- get max pos for old req line items in case of new commodity_code 
	SELECT NVL(MAX(rli_pos),0)
    INTO max_pos
    FROM m_req_line_items
   WHERE r_id = p_r_id
     AND rli_pos >= 0
	 ;
	 -- get max commodity_code pos 
	 SELECT NVL(MAX(rli_pos),max_pos + v_pd_zr_rliinc )
    INTO new_pos
	--FROM m_req_line_items
    FROM m_req_line_items rli,m_idents i
   WHERE r_id = p_r_id
     -- ignore new rli (last_RLI_id is not null or pos is not negative )
     AND rli_pos >= 0
	 --join ident---- 
	 And rli.ident = i.ident 
	 -- filter by record commodity_id
	 and i.commodity_id= commodity_code_rec.commodity_id
	 ;
    /* To avoid a violation of the unique key we set the */
    /* position to a negative value in the first step.   */
--    new_pos     := new_pos - 1;
--    new_sub_pos := - 1;
    --new_pos     := new_pos + v_pd_zr_rliinc; 
--    new_sub_pos := 0;

	SELECT NVL(MAX(rli_sub_pos),0)
    INTO new_sub_pos
    FROM m_req_line_items
   WHERE r_id = p_r_id
	 AND rli_pos = new_pos
     AND rli_pos >= 0;
	 
--    UPDATE m_req_line_items
--    SET    rli_pos     = new_pos,
--           rli_sub_pos = new_sub_pos
--    WHERE  rli_id = commodity_code_rec.rli_id;

    IF NOT rli_cur%ISOPEN THEN
      OPEN rli_cur;
    END IF;

    FETCH rli_cur INTO rli_rec;

    WHILE rli_cur%FOUND LOOP

--      new_sub_pos := new_sub_pos - 1;
      new_sub_pos := new_sub_pos + v_pd_zr_rliinc;

	IF rli_rec.last_rli_id IS NULL THEN
      UPDATE m_req_line_items
      SET    rli_pos     = new_pos,
             rli_sub_pos = new_sub_pos
      WHERE  rli_id = rli_rec.rli_id;
	END IF;
	
      FETCH rli_cur INTO rli_rec;

    END LOOP;

    CLOSE rli_cur;

    FETCH commodity_code_cur INTO commodity_code_rec;

  END LOOP;

  CLOSE commodity_code_cur;

--  IF NOT rli_man_cur%ISOPEN THEN
--    OPEN rli_man_cur;
--  END IF;
--
--  FETCH rli_man_cur INTO commodity_code_rec;
--
--  /* manual line items */
--  WHILE rli_man_cur%FOUND LOOP
--
--    /* To avoid a violation of the unique key we set the */
--    /* position to a negative value in the first step.   */
----    new_pos     := new_pos - 1;
----    new_sub_pos := - 1;
--    new_pos     := new_pos + v_pd_zr_rliinc;
--    new_sub_pos := 1;
--
--    UPDATE m_req_line_items
--    SET    rli_pos     = new_pos,
--           rli_sub_pos = new_sub_pos
--    WHERE  rli_id = commodity_code_rec.rli_id;
--
--    FETCH rli_man_cur INTO commodity_code_rec;
--
--  END LOOP;
--
--  CLOSE rli_man_cur;

--  UPDATE m_req_line_items
--     SET rli_pos = - rli_pos,
--         rli_sub_pos = - rli_sub_pos
--   WHERE r_id = p_r_id;

--EXCEPTION WHEN OTHERS THEN
--  ROLLBACK;

  IF commodity_code_cur%ISOPEN THEN
    CLOSE commodity_code_cur;
  END IF;

  IF rli_cur%ISOPEN THEN
    CLOSE rli_cur;
  END IF;

  IF rli_man_cur%ISOPEN THEN
    CLOSE rli_man_cur;
  END IF;



