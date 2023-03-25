SELECT
	b.ucid,
	b.housedel_id,
	d.first_occur_time,
	g.first_offline_time,
	h.sign_time
-- 贝壳页面浏览
FROM (
	SELECT
		a.ucid AS ucid,
		a.housedel_id AS housedel_id
	FROM (
		SELECT
			u.ucid AS ucid,
			u.housedel_id AS housedel_id,
			u.pt,
			u.uicode
		FROM rpt.rpt_comm_raw_log_beike_behivior_path_di u
		JOIN (
			SELECT 
				uicode,
				pt
			FROM rpt.rpt_log_bi_user_uicode_flow_di				-- 贝壳平台
			WHERE pt BETWEEN '20211001000000'  AND '20220131000000'
			AND is_ershou_hefang = 1
			GROUP BY uicode, pt
		) v
		ON u.uicode = v.uicode AND u.pt = v.pt
		WHERE u.pt BETWEEN '20211001000000'  AND '20220131000000'
		AND u.ucid != '-911'
		AND u.housedel_id != '-911'
		AND u.city_code IN (110000,310000,440100,440300,510100,120000,610100,500000)	-- 北京；上海；广州；深圳；成都；天津；西安；重庆
		AND u.pid = 'bigc_app_ershou'		-- 二手业务
	) a
	GROUP BY a.ucid, a.housedel_id
) b
-- 商机
LEFT JOIN (
	SELECT
		c.cust_ucid,
		c.housedel_id,
		MIN(occur_time) AS first_occur_time
	FROM rpt.rpt_asm_sj_detail_di c
	WHERE c.pt BETWEEN '20211001000000'  AND '20220131000000'
	AND c.commercial_type_code IN (900004001,900004002,900004004) 		-- 900004001:400,900004002:IM,900004004:VR带看
	AND c.housedel_id != '-911'
	AND c.is_cust_send = 1                            		-- 用户主动发起
	AND c.business_code = 909100002							-- 业务线：二手
	AND c.city_code IN (110000,310000,440100,440300,510100,120000,610100,500000)
	GROUP BY c.cust_ucid, c.housedel_id
) d
ON b.ucid = d.cust_ucid AND b.housedel_id = d.housedel_id
-- 线下看房
LEFT JOIN (
	SELECT
		e.housedel_id AS housedel_id,
		e.first_offline_time,
		f.cust_ucid AS ucid
	FROM(
		SELECT
			housedel_id,
			custdel_id,
			MIN(showing_start_time) AS first_offline_time
		FROM rpt.rpt_comm_show_showing_housedel_info_da
		WHERE pt = '20220131000000'						
		AND city_code IN (110000,310000,440100,440300,510100,120000,610100,500000)
		AND del_type_code = 990001001						-- 990001001 委托类型：买卖
		AND substr(showing_start_time,1,7) BETWEEN '2021-10' AND '2022-01'
		GROUP BY housedel_id,custdel_id
	) e
	-- 客源宽表
	JOIN (
		SELECT
			cust_ucid,
			custdel_id
		FROM rpt.rpt_comm_cdel_custdel_basic_info_da
		WHERE pt = '20220201000000'						-- 新表更改pt
		AND city_code IN (110000,310000,440100,440300,510100,120000,610100,500000)
	) f
	ON e.custdel_id = f.custdel_id
) g
ON b.ucid = g.ucid AND b.housedel_id = g.housedel_id
-- 成交
LEFT JOIN (
	SELECT 
		cust_ucid,
		housedel_id,
		MIN(sign_time) AS sign_time  					-- 成交时间，示例2021-10-25 20:46:27 
	FROM rpt.rpt_shh_deal_agreement_da
	WHERE pt = '20220705000000'							-- 新表更改pt
	AND status_code in (150005002,150005003,150005006)	-- 150005002:合同-签约,150005003:合同-过户,150005006:合同-完结
	AND del_type_code = 990001001 						-- 990001001:买卖,990001002:租赁,990001007:商业
	AND agreement_type_code = 150001001 				-- 150001001:合同,150001002:定金,150001003:意向金
	AND is_parent_agreement = 1 			-- 是否主协议
	AND is_commit = 1 						-- 是否提交
	AND substr(sign_time,1,7) BETWEEN '2021-10' AND '2022-01'
	AND city_code IN (110000,310000,440100,440300,510100,120000,610100,500000)
	GROUP BY cust_ucid,housedel_id
) h
ON b.ucid = h.cust_ucid AND b.housedel_id = h.housedel_id

