--- M_PCK_REQ_CUSTOM
v_pd_zr_rliinc     NUMBER;

  /* MTO line items */
  CURSOR rli_cur IS
      SELECT DISTINCT cc.commodity_id, cc.part_id, cc.commodity_code
        FROM m_req_line_items rli
        LEFT JOIN m_idents i ON i.ident = rli.ident
        LEFT JOIN m_commodity_codes cc ON cc.commodity_id = i.commodity_id
       WHERE rli.r_id = p_r_id
--         AND rli.rli_sub_pos = 1
         AND rli.rli_sub_pos < 0
         AND rli.manual_ind = 'N'
--         AND rli.last_rli_id IS NULL;
--         AND i.ident = rli.ident
--         AND cc.commodity_id = i.commodity_id
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

   rli_rec           rli_cur%ROWTYPE;

   /* MTO sub line items (sub > 1) */
   CURSOR rli_sub_cur IS
      SELECT rli.rli_id, rli.last_rli_id
        FROM m_req_line_items rli
		LEFT JOIN m_idents i ON i.ident = rli.ident
		LEFT JOIN m_commodity_codes cc ON cc.commodity_id = i.commodity_id
       WHERE rli.r_id = p_r_id
--         AND rli.rli_pos = rli_rec.rli_pos
--         AND rli.rli_sub_pos > 1
         AND rli.rli_sub_pos < 0
         AND rli.manual_ind = 'N'
--         AND rli.last_rli_id IS NULL
--         AND i.ident = rli.ident
         AND cc.commodity_id = rli_rec.commodity_id
       ORDER BY to_number(i.input_1), to_number(i.input_2);

   rli_sub_rec       rli_sub_cur%ROWTYPE;
   
   new_pos           NUMBER := 0;
   new_sub_pos       NUMBER := 0;




  SELECT NVL(TO_NUMBER(m_pck_ppd_defaults.get_value('ZR_RLIINC')),1)
  INTO v_pd_zr_rliinc
  FROM dual;

  UPDATE m_req_line_items
     SET rli_pos = - rli_pos,
         rli_sub_pos = - rli_sub_pos
   WHERE r_id = p_r_id
     AND last_rli_id IS NULL;

  SELECT NVL(MAX(rli_pos),0)
    INTO new_pos
    FROM m_req_line_items
   WHERE r_id = p_r_id
     AND rli_pos >= 0;

  IF NOT rli_cur%ISOPEN THEN
    OPEN rli_cur;
  END IF;

  FETCH rli_cur INTO rli_rec;

  /* MTO line items */
  WHILE rli_cur%FOUND LOOP

    /* To avoid a violation of the unique key we set the */
    /* position to a negative value in the first step.   */
--    new_pos     := new_pos - 1;
--    new_sub_pos := - 1;
    new_pos     := new_pos + v_pd_zr_rliinc;
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
--    WHERE  rli_id = rli_rec.rli_id;

    IF NOT rli_sub_cur%ISOPEN THEN
      OPEN rli_sub_cur;
    END IF;

    FETCH rli_sub_cur INTO rli_sub_rec;

    WHILE rli_sub_cur%FOUND LOOP

--      new_sub_pos := new_sub_pos - 1;
      new_sub_pos := new_sub_pos + 1;

	IF rli_sub_rec.last_rli_id IS NULL THEN
      UPDATE m_req_line_items
      SET    rli_pos     = new_pos,
             rli_sub_pos = new_sub_pos
      WHERE  rli_id = rli_sub_rec.rli_id;
	END IF;
	
      FETCH rli_sub_cur INTO rli_sub_rec;

    END LOOP;

    CLOSE rli_sub_cur;

    FETCH rli_cur INTO rli_rec;

  END LOOP;

  CLOSE rli_cur;

--  IF NOT rli_man_cur%ISOPEN THEN
--    OPEN rli_man_cur;
--  END IF;
--
--  FETCH rli_man_cur INTO rli_rec;
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
--    WHERE  rli_id = rli_rec.rli_id;
--
--    FETCH rli_man_cur INTO rli_rec;
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

  IF rli_cur%ISOPEN THEN
    CLOSE rli_cur;
  END IF;

  IF rli_sub_cur%ISOPEN THEN
    CLOSE rli_sub_cur;
  END IF;

  IF rli_man_cur%ISOPEN THEN
    CLOSE rli_man_cur;
  END IF;



