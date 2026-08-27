-- exp_s3.vista_fundos_prd_v2 source

CREATE OR REPLACE VIEW exp_s3.vista_fundos_prd_v2
AS SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD_POSTGRE_PORTAL_PRD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    ucv.type_enum AS tipo_cliente,
    ucv.portfolio_portfoliocode_ AS pf_code
   FROM trf_s3.users_prd_v2 ucv
     JOIN exp_s3.api_fund af ON 1 = 1
  WHERE ucv.type_enum = ANY (ARRAY['MASTER_BO'::text, 'OPERATOR BACKOFFICE NO GROUP'::text])
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD_POSTGRE_PORTAL_PRD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    ucv.type_enum AS tipo_cliente,
    ucv.portfolio_portfoliocode_ AS pf_code
   FROM trf_s3.users_prd_v2 ucv
     JOIN sc_apis.api_portifoliofunds ap ON ucv.portfolio_portfoliocode_ = ap.ptf_code::text
     JOIN exp_s3.api_fund af ON ap.funds::text = af.internalcodefund
  WHERE ucv.type_enum = ANY (ARRAY['MASTER CLIENTE'::text, 'OPERATOR CLIENTE NO GROUP'::text])
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD_POSTGRE_PORTAL_PRD\'::text || ucv.login_ AS "USERID",
    ucv.cnpj AS "REDUCTION_CNPJ",
    ucv.fundcode_ AS "REDUCTION_CLIENTE",
    ucv.type_enum AS tipo_cliente,
    ucv.portfolio_portfoliocode_ AS pf_code
   FROM trf_s3.users_prd_v2 ucv
  WHERE ucv.type_enum = ANY (ARRAY['OPERATOR CLIENTE WITH GROUP'::text, 'OPERATOR BO WITH GROUP'::text])
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'T000023'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'T000055'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'T000199'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'T000362'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'T000367'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'svc.prd.qlikrobo'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'svc.prd.qneprt'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'ADMIN'::text AS "ROL_QS",
    'INTERNAL\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'SA_SCHEDULER'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'ADMIN'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'NFQ'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'SVC.PRD.QLIK'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'BULLE'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'svc.prd.portalreport'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'BULLE'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'svc.cer.portalreport'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1
UNION ALL
 SELECT DISTINCT 'USER'::text AS "ROL_QS",
    'CLOUD\'::text || ucv.login_ AS "USERID",
    af.fundcnpj AS "REDUCTION_CNPJ",
    af.internalcodefund AS "REDUCTION_CLIENTE",
    'PORTAL'::text AS tipo_cliente,
    NULL::text AS pf_code
   FROM ( SELECT 'svc.prd.qneprt'::text AS login_) ucv
     JOIN exp_s3.api_fund af ON 1 = 1;