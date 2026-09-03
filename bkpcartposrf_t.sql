-- DROP FUNCTION trf_s3.function_meg_cart_pos_rf_t();

CREATE OR REPLACE FUNCTION trf_s3.function_meg_cart_pos_rf_t()
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$

--DO $$ --Quitar esta linea
DECLARE 
    c_reprocess REFCURSOR;
    v_dat_min DATE;
    v_dat_max DATE;
    v_fund VARCHAR(1000);
    v_fund_2 VARCHAR(1000);
    v_cod_dmesco BIGINT;
    v_row_count2 NUMERIC(8);
    v_row_count_delete NUMERIC(8) := 0;
    v_status VARCHAR(1000);
    v_dat_pos DATE;
    v_cod_dmesco_2 BIGINT;
    v_cod_cont NUMERIC(10) := 4;
    v_cliente_actual TEXT := NULL;
	reco record;
    c_cursor CURSOR FOR 
        select distinct  MGCCLI.cod_idmgec
        FROM trf_s3.SSS_POSITION_T a
        INNER JOIN trf_s3.SSS_EST_COM_MGC_T MGCCLI on 
            a.COD_DMESCA = MGCCLI.COD_DMESCO AND MGCCLI.COD_DMTNEC = 4
            where a.cod_flag_mapeo is null 
            order by 1;
    v_cliente_id VARCHAR(50);
    c_cursor2 CURSOR FOR 
        select distinct  MGCCLI.cod_idmgec,a.dat_valuat
        FROM trf_s3.SSS_POSITION_T a
        INNER JOIN trf_s3.SSS_EST_COM_MGC_T MGCCLI on 
            a.COD_DMESCA = MGCCLI.COD_DMESCO AND MGCCLI.COD_DMTNEC = 4
            where a.cod_flag_mapeo is null 
            order by 1,2;
    v_cliente_id2 VARCHAR(50);
    v_data2 VARCHAR(50);
	record RECORD;
BEGIN 
raise notice '% Comienza la funcion', clock_timestamp();
execute 'drop table if exists MAINDETPRDUR';
execute 'drop table if exists cancelledcuscominst';
execute 'drop table if exists filtered_asset';
execute 'drop table if exists DETPRPUPAR';
execute 'drop table if exists DETPRHTM';
raise notice '% se crea MAINDETPRDUR', clock_timestamp();
create temp table MAINDETPRDUR AS (
select MAX(AMT_DURMACULAY) as AMT_DURMACULAY, max(amt_yieldmaturity)                               as amt_yieldmaturity,
                DAT_GENER, cast(DETPRDUR.COD_DMASSE as numeric) AS COD_DMASSE, MAX(amt_nbrdaystom)    as amt_nbrdaystom
from trf_s3.SSS_DETPR_CRITERION_T as DETPRDUR
inner join trf_s3.SSS_ASSET_T A on A.COD_DMASSE = cast(DETPRDUR.COD_DMASSE as numeric) and a.cod_dmasfm in (1, 7)
where COD_CONFIGIDE = 'PuMTM'
group by DAT_GENER, DETPRDUR.COD_DMASSE
);
create temp table DETPRHTM AS (
select MAX(AMT_DURMACULAY) as AMT_DURMACULAY, max(amt_yieldmaturity)               as amt_yieldmaturity,
DAT_GENER, CAST(DETPRHTM.COD_DMASSE AS NUMERIC)                      AS cod_dmasse                     ,
MAX(amt_nbrdaystom)                                                  as            amt_nbrdaystom
from trf_s3.SSS_DETPR_CRITERION_T as DETPRHTM
inner join trf_s3.SSS_ASSET_T A on A.COD_DMASSE = cast(DETPRHTM.COD_DMASSE as numeric) and a.cod_dmasfm in (1, 7)
where COD_CONFIGIDE = 'HTMPrice'
group by DAT_GENER, DETPRHTM.COD_DMASSE
);
create temp table DETPRPUPAR AS (
SELECT 
    D.DAT_GENER                                   ,
    CAST(D.COD_DMASSE AS NUMERIC)    AS cod_dmasse,
    MAX(D.AMT_PUPAR)              AS AMT_PUPAR
FROM 
    trf_s3.SSS_DETPR_CRITERION_T AS D
WHERE 
    D.COD_CONFIGIDE = 'PU PAR'
    AND EXISTS (
        SELECT 1 
        FROM trf_s3.SSS_ASSET_T AS A 
        WHERE A.COD_DMASSE = CAST(D.COD_DMASSE AS NUMERIC) 
          AND A.cod_dmasfm IN (1, 7)
    )
GROUP BY 
    D.DAT_GENER, 
    D.COD_DMASSE
);
raise notice '% se crea cancelledcuscominst', clock_timestamp();
create temp table cancelledcuscominst as (
    SELECT
        inst.des_appref AS des_appref, 'S' AS Oper_Termo, inst.dat_traded AS dat_traded, inst.dat_theori AS dat_theori
    FROM trf_s3.sss_cus_com_ins_t inst
    WHERE inst.des_status <> 'CANCELLED'
);
create index x1_cancel on cancelledcuscominst( des_appref,dat_traded, dat_theori);
raise notice '% se crea filtered_asset', clock_timestamp();
create temp table filtered_asset as (
    SELECT cod_traast,cod_dmasse
    FROM trf_s3.SSS_ASSET_T
    WHERE cod_dmasfm IN (1, 7)
);
raise notice '% Empieza reproceso', clock_timestamp();
    OPEN c_reprocess FOR 
        select  cod_dmesco, cod_cli, dt_min, dt_max
        FROM exp_s3.control_carga_sac_megara_t 
        WHERE meg_table = 'SSS_POSITION_T'  AND control_qlik = 0;
    LOOP
        FETCH c_reprocess INTO v_cod_dmesco, v_fund, v_dat_min, v_dat_max;
        EXIT WHEN NOT FOUND;
		insert into trf_s3.s3_carga_megara (name_table, cliente, dat_megara, name_qvd, name_field_date, ic_qlik_read) values ('cart_pos_rf_t', split_part(v_fund,'|',1), V_DAT_MIN, 'sac_qlik_cart_pos_rf_v', 'dat_hist', null);
        FOR record IN
            SELECT MGCCLI.cod_idmgec, a.dat_valuat 
            FROM trf_s3.SSS_POSITION_T a
            inner join trf_s3.SSS_EST_COM_MGC_T MGCCLI on a.COD_DMESCA = MGCCLI.COD_DMESCO AND MGCCLI.COD_DMTNEC = 4
            WHERE split_part( MGCCLI.cod_idmgec,'|',1) = v_fund  AND dat_valuat BETWEEN v_dat_min AND v_dat_max 
        LOOP    
            v_fund_2 := split_part(record.cod_idmgec,'|',1);
            v_dat_pos := record.dat_valuat;
			delete from trf_s3.cart_pos_rf_t spcpt where cod_cli = v_fund_2 and dat_hist = v_dat_pos and base_id = 0;
        END LOOP;
    END LOOP;
    CLOSE c_reprocess;
raise notice '% Termina reproceso', clock_timestamp();
    OPEN c_cursor2;
    LOOP
        FETCH c_cursor2 INTO v_cliente_id2, v_data2;
        EXIT WHEN NOT FOUND;
        IF v_cliente_id2 IS DISTINCT FROM v_cliente_actual THEN
            raise NOTICE '% Cliente a trabajar  %', clock_timestamp(), v_cliente_id2;
            v_cliente_actual := v_cliente_id2;
        END IF;
        raise NOTICE '%             Fecha a trabajar:  %', clock_timestamp(),v_data2;
    END LOOP;
    CLOSE c_cursor2;
OPEN c_cursor;
    LOOP
        FETCH c_cursor INTO v_cliente_id;
        EXIT WHEN NOT FOUND;
        raise notice '% Se abre el cliente: %',  clock_timestamp(),v_cliente_id;
        execute 'drop table if exists CGCPositionGroupBy';
        execute 'drop table if exists DETCASH';
        execute 'drop table if exists filtered_detcash';
        execute 'drop table if exists MAX_VALPORCS';
        execute 'drop table if exists P2';
        execute 'drop table if exists POSI';
        execute 'drop table if exists PUPar';
        execute 'drop table if exists YieldCurve';
        execute 'drop table if exists filtered_position';
        execute 'drop table if exists POSI_HeldToMaturity';
    raise notice '% se crea MAX_VALPORCS', clock_timestamp();
    create temp table MAX_VALPORCS AS (
        SELECT MAX(e.dat_update) AS dat_update,
                e.des_owner                   ,
                e.dat_valuat
            FROM trf_s3.sss_position_t e
			INNER JOIN filtered_asset fa ON fa.cod_dmasse = e.cod_dmasse
            WHERE e.cod_flag_mapeo is null
            and e.des_owner = v_cliente_id
        GROUP BY e.des_owner,
                e.dat_valuat
        );
		CREATE INDEX xmaxvalprocs ON MAX_VALPORCS( des_owner, dat_update, dat_valuat);
    raise notice '% se crea POSI', clock_timestamp();
    create temp table POSI AS (
        SELECT MAX(e.DAT_QLIKUPDATE)               AS DAT_QLIKUPDATE,
                MAX(e.dat_update)    AS dat_update                  ,
                MAX(e.AMT_ASSEPR)    AS AMT_ASSEPR                  ,
                MAX(e.AMT_INDEXPR)   AS AMT_INDEXPR                 ,
                e.cod_dmasse                                        ,
                e.des_owner                                         ,
                e.dat_valuat                                        ,
                e.COD_FLAG_MAPEO
            FROM trf_s3.sss_position_t e
			INNER JOIN filtered_asset fa ON fa.cod_dmasse = e.cod_dmasse
                                               inner join MAX_VALPORCS f on
                                                               f.des_owner = e.des_owner
                                                               and f.dat_update = e.dat_update
                                                               and f.dat_valuat = e.dat_valuat
            WHERE e.des_posnat IN ('Settled', 'ReverseRepo', 'Pledged', 'HeldToMaturity')
            AND e.cod_flag_mapeo is null
            and e.des_owner = v_cliente_id
       GROUP BY e.dat_valuat   ,
                e.des_owner    ,
                e.cod_dmasse   ,
                e.COD_FLAG_MAPEO
        );
    raise notice '% se crea POSI_HeldToMaturity', clock_timestamp();		
	create temp table POSI_HeldToMaturity as (
		select
			e.DAT_QLIKUPDATE,
			e.dat_update    ,
			e.AMT_ASSEPR    ,
            e.AMT_INDEXPR   ,
			e.cod_dmasse    ,
			e.des_owner     ,
			e.dat_valuat    ,
			e.amt_posqua    ,
			e.COD_FLAG_MAPEO,
			e.des_posnat    ,
			e.des_contractref
		from
			trf_s3.sss_position_t e
		inner join MAX_VALPORCS f on
			f.des_owner = e.des_owner
			and f.dat_update = e.dat_update
			and f.dat_valuat = e.dat_valuat
		where
			e.des_posnat in ('HeldToMaturity')
			and e.cod_flag_mapeo is null
			and e.des_owner = v_cliente_id
				);	
    raise notice '% se crea P2', clock_timestamp();
    create temp table P2 AS (
        SELECT MAX(e.DAT_QLIKUPDATE)               AS DAT_QLIKUPDATE,
                MAX(e.dat_update)    AS dat_update                  ,
                MAX(e.AMT_ASSEPR)    AS AMT_ASSEPR                  ,
                MAX(e.AMT_INDEXPR)   AS AMT_INDEXPR                 ,
                e.cod_dmasse                                        ,
                e.des_owner                                         ,
                e.dat_valuat                                        ,
                e.COD_FLAG_MAPEO
            FROM trf_s3.sss_position_t e
            WHERE e.des_posnat = 'ReverseRepo'
            AND e.cod_flag_mapeo is null
            and e.des_owner = v_cliente_id
        GROUP BY e.dat_valuat   ,
                e.des_owner     ,
                e.cod_dmasse    ,
                e.COD_FLAG_MAPEO,
                e.COD_FLAG_MAPEO
having sum(e.amt_posqua) <> 0        
        );
    raise notice '% se crea filtered_position',clock_timestamp();
    create temp table filtered_position AS (
        SELECT ass.cod_traast
            FROM filtered_asset ass
            INNER JOIN trf_s3.SSS_POSITION_T pos ON pos.cod_dmasse = ass.cod_dmasse
            WHERE pos.cod_flag_mapeo is null
            and  pos.des_owner = v_cliente_id
        );
    raise notice '% se crea filtered_detcash',clock_timestamp();
create temp table filtered_detcash AS (
        SELECT                    cod_tradasset,
                dat_generate                   ,
                dat_start                      ,
                dat_end                        ,
                amt_capital                    ,
                amt_coupamount                 ,
                amt_hcutpricingdt              ,
                amt_credspread
            FROM trf_s3.SSS_DETCASH_FLOW_T
            WHERE des_configide = 'PuMTM'
            and amt_capital > 0
            AND cod_tradasset IN ( SELECT cod_traast FROM filtered_position ));
    raise notice '% se crea DETCASH',clock_timestamp();
    create temp table DETCASH AS (
        SELECT MAX(fd.amt_capital)        AS amt_capital                        ,
                MAX(fd.amt_coupamount)    AS amt_coupamount                     ,
                MAX(fd.amt_hcutpricingdt)                   AS amt_hcutpricingdt,
                MAX(fd.amt_credspread)    AS amt_credspread                     ,
                fd.dat_generate                                                 ,
                fd.cod_tradasset                                                ,
                fd.dat_start                                                    ,
                fd.dat_end
            FROM filtered_detcash fd
        GROUP BY fd.dat_generate,
                fd.cod_tradasset,
                fd.dat_start    ,
                fd.dat_end
        );
    create temp table YieldCurve AS (
        SELECT MAX(P.AMT_CLOPRI) AS AMT_CLOPRI,
                POSI3.DES_OWNER               ,
                POSI3.COD_DMASSE              ,
                POSI3.DAT_VALUAT
            FROM trf_s3.SSS_POSITION_T POSI3
        LEFT JOIN TRF_S3.SSS_PRICES_T P ON P.COD_SECPRICEID::TEXT = POSI3.COD_PRICESETPK
            WHERE POSI3.COD_RCRDTYP = 'Position'
            AND P.DES_PROVID = 'Yield Curve'
            AND POSI3.cod_flag_mapeo is null
            and posi3.des_owner = v_cliente_id
        GROUP BY POSI3.DES_OWNER,
                POSI3.COD_DMASSE,
                POSI3.DAT_VALUAT
        );
    raise notice '% se crea PUPar', clock_timestamp();                    
    create temp table PUPar AS (
        SELECT MAX(P.AMT_CLOPRI) AS AMT_CLOPRI,
                POSI4.DES_OWNER               ,
                POSI4.COD_DMASSE              ,
                POSI4.DAT_VALUAT
            FROM trf_s3.SSS_POSITION_T POSI4
        LEFT JOIN TRF_S3.SSS_PRICES_T P ON P.COD_SECPRICEID::TEXT = POSI4.COD_PRICESETPK
            WHERE POSI4.COD_RCRDTYP = 'Position'
            AND P.DES_PROVID = 'PU Par'
            AND POSI4.cod_flag_mapeo is null
            and posi4.des_owner = v_cliente_id
        GROUP BY POSI4.DES_OWNER,
                POSI4.COD_DMASSE,
                POSI4.DAT_VALUAT
        );
    raise notice '% se crea CGCPositionGroupBy', clock_timestamp();                    
    create temp table CGCPositionGroupBy AS (
        select                         scp.cod_owner                ,
				scp.dat_nav                                                     ,
				scp.cod_dmasse                                                  ,
				scp.des_evtref                     Oper                         ,
				scp.des_origref                                                 ,
				SUM(coalesce(scp.amt_qty, 0))      as amt_qty                   ,
				scp.DES_EVTREF                                                  ,
				scp.cod_posnature                                               ,
				MAX(scp.DAT_TRADE)                 as DAT_TRADE                 ,
				SUM(coalesce(scp.AMT_BOOKAM, 0))   as AMT_BOOKAM                ,
				SUM(coalesce(scp.AMT_TRCOSAMO, 0))               as AMT_TRCOSAMO,
				MAX(scp.AMT_BOOKC)                 as            AMT_BOOKC
			from
				trf_s3.sss_cgc_position_t scp
			inner join MAX_VALPORCS mv on
				mv.des_owner = scp.cod_owner
				and mv.dat_valuat = scp.dat_nav
			where
				scp.cod_owner = v_cliente_id
				and
			scp.DAT_POSITION <= scp.DAT_NAV
				and
			scp.DAT_VALIDITY > scp.DAT_NAV
				and
			scp.des_evtref not like 'DPG%'
			group by
				scp.cod_owner     ,
				scp.dat_nav       ,
				scp.cod_dmasse    ,
				scp.des_evtref    ,
				scp.des_origref   ,
				scp.cod_posnature);
    raise notice '% Empieza select : %',clock_timestamp(), v_cliente_id;
    raise notice '% Inicia creacion de TEM_meg_cart_pos_rf_t',clock_timestamp();
    execute 'drop table if exists TEM_meg_cart_pos_rf_t';
    create temp table TEM_meg_cart_pos_rf_t as (
		select
			COD_OPTERMO       ,
			COD_INST          ,
			AMT_BLOCK_QT      ,
			AMT_DAY_ACQUI_MAT ,
			AMT_DAY_UTIL_MAT  ,
			dat_hist          ,
			DAT_ACQUI         ,
			DAT_EMISS         ,
			DAT_MATURITY      ,
			DAT_RESG          ,
			COD_NEG_VENC      ,
			COD_INDEX         ,
			AMT_TAX_OVER      ,
			AMT_DISP_PAP_QT   ,
			COD_RF_LASTRO     ,
			COD_RFOPER        ,
			COD_RF_TYP        ,
			COD_MTM           ,
			AMT_AGIO          ,
			AMT_AP            ,
			AMT_APLI          ,
			AMT_BRUTO_POS     ,
			AMT_CM            ,
			AMT_COUPON        ,
			AMT_PAP_DUR       ,
			AMT_JUROS         ,
			AMT_LIQ_POS_IRRF  ,
			AMT_PRIZE         ,
			AMT_PRINC         ,
			AMT_PROV_IOF      ,
			AMT_PROV_IRRF     ,
			AMT_PU            ,
			AMT_PU_AJUS_MTM   ,
			AMT_PU_ACQUI      ,
			AMT_PU_CURVA      ,
			AMT_PU_MERC       ,
			AMT_PU_NOMINAL    ,
			AMT_RESG          ,
			AMT_TAX_AA        ,
			AMT_TIR           ,
			AMT_TIR_MERC      ,
			AMT_RESG_OP_COMPR ,
			COD_CLI           ,
			COD_ORIGEM        ,
			AMT_AJUS          ,
			AMT_BRUTO_GER     ,
			AMT_PU_AGIO       ,
			AMT_PU_EMIS_CM    ,
			AMT_PU_EMIS_JUROS ,
			AMT_PU_EMIS_PRIZE ,
			AMT_PU_EMIS_PRINC ,
			AMT_TIR_CURVA     ,
			DES_NME           ,
			AMT_VENDA_TERMO   ,
			AMT_PU_PAR        ,
			DAT_QLIKUPDATE    ,
			COD_SACBBDD       ,
			concatenate
		from
			(
			select
		coalesce(pos_termo.oper_termo, 'N') as COD_OPTERMO                       ,
		c.COD_ISSUERID                      as COD_INST                          ,
		b.Qtd_Bloqueada                     as AMT_BLOCK_QT                      ,
		DETPRDUR1.amt_nbrdaystom            as                  AMT_DAY_ACQUI_MAT,
		DETPRDUR2.amt_nbrdaystom            as AMT_DAY_UTIL_MAT                  ,
		POSI.DAT_VALUAT                     as dat_hist                          ,
		b.dat_trade                         as DAT_ACQUI                         ,
		a.DAT_ISSUE                         as DAT_EMISS                         ,
		a.DAT_MATURI                        as DAT_MATURITY                      ,
		CD.DAT_MATURITY                     as DAT_RESG                          ,
		case
			when b.COD_POSNATURE = 'HeldToMaturity' then 'V'
			else 'N'
		end as COD_NEG_VENC       ,
		I.COD_REFRATE as COD_INDEX,
		case
			when DETCASH.AMT_HCUTPRICINGDT is not null then (1 + (DETCASH.AMT_HCUTPRICINGDT / 100) ^ (1 / 252))
			when DETCASH.AMT_CREDSPREAD is not null then (1 + (DETCASH.AMT_CREDSPREAD / 100) ^ (1 / 252))
		end as AMT_TAX_OVER                      ,
		b.Qtd_Livre as AMT_DISP_PAP_QT           ,
		a.COD_TRAAST as COD_RF_LASTRO            ,
        left(B.DES_EVTREF,15) as COD_RFOPER,
		e.COD_ID as COD_RF_TYP                   ,
		case
			when b.COD_POSNATURE = 'HeldToMaturity' then 'V'
			else 'N'
		end as COD_MTM,
		0 as AMT_AGIO ,
		case
			when B.COD_POSNATURE = 'ReverseRepo' then -1
			else 1
		end as AMT_AP           ,
		B.AMT_BOOKAM as AMT_APLI,
		case
            when B.COD_POSNATURE = 'ReverseRepo' then coalesce(P2.AMT_INDEXPR,P2.AMT_ASSEPR) * b.Qtd_Total
            when b.cod_posnature = 'HeldToMaturity' then coalesce(htm.AMT_INDEXPR,htm.AMT_ASSEPR) * b.Qtd_Total
            else coalesce(POSI.AMT_INDEXPR,POSI.AMT_ASSEPR) * b.Qtd_Total
        end as AMT_BRUTO_POS                                            ,
		(DETCASH.AMT_CAPITAL - A.AMT_ISSUPRICE) * B.Qtd_Total as AMT_CM,
		DETPRDUR2.amt_yieldmaturity as AMT_COUPON                      ,
		DETPRDUR1.AMT_DURMACULAY as AMT_PAP_DUR                        ,
		DETPRPUPAR.AMT_PUPAR as AMT_JUROS                              ,
		case
            when B.COD_POSNATURE = 'ReverseRepo' then coalesce(P2.AMT_INDEXPR, P2.AMT_ASSEPR) * b.Qtd_Total
            when b.cod_posnature = 'HeldToMaturity' then coalesce(htm.AMT_INDEXPR, htm.AMT_ASSEPR) * b.Qtd_Total
            else coalesce(POSI.AMT_INDEXPR, POSI.AMT_ASSEPR) * b.Qtd_Total
        end as AMT_LIQ_POS_IRRF    ,
		0 as AMT_PRIZE             ,
		B.AMT_TRCOSAMO as AMT_PRINC,
		0 as AMT_PROV_IOF          ,
		0 as AMT_PROV_IRRF         ,
		 case
            when B.COD_POSNATURE = 'ReverseRepo' then coalesce(P2.AMT_INDEXPR, P2.AMT_ASSEPR)
            when B.COD_POSNATURE = 'HeldToMaturity' then coalesce(htm.AMT_INDEXPR, htm.AMT_ASSEPR)
            else coalesce(POSI.AMT_INDEXPR, POSI.AMT_ASSEPR)
        end as AMT_PU,
		0 as AMT_PU_AJUS_MTM       ,
		B.AMT_BOOKC as AMT_PU_ACQUI,
		0 as AMT_PU_CURVA          ,
         case
            when B.COD_POSNATURE = 'HeldToMaturity' then coalesce(htm.AMT_INDEXPR, htm.AMT_ASSEPR)
            else coalesce(POSI.AMT_INDEXPR, POSI.AMT_ASSEPR)
         end as AMT_PU_MERC         ,
		DETCASH.AMT_CAPITAL as AMT_PU_NOMINAL,
		0 as AMT_RESG                        ,
		0 as AMT_TAX_AA                      ,
		DETPRHTM.AMT_YIELDMATURITY as AMT_TIR,
		case
			when DETCASH.AMT_HCUTPRICINGDT is not null then DETCASH.AMT_HCUTPRICINGDT
			else DETCASH.AMT_CREDSPREAD
		end as AMT_TIR_MERC                               ,
		coalesce(CD.AMT_MATAMOUNT, 0) as AMT_RESG_OP_COMPR,
		POSI.DES_OWNER as COD_CLI                         ,
		'N' as COD_ORIGEM                                 ,
        case
            when B.COD_POSNATURE = 'ReverseRepo' then (
                coalesce(P2.AMT_INDEXPR, P2.AMT_ASSEPR) - coalesce(YieldCurve.AMT_CLOPRI, 0)
            )
            when B.COD_POSNATURE = 'HeldToMaturity' then (
                coalesce(htm.AMT_INDEXPR, htm.AMT_ASSEPR) - coalesce(YieldCurve.AMT_CLOPRI, 0)
            )
            else (
                coalesce(POSI.AMT_INDEXPR, POSI.AMT_ASSEPR) - coalesce(YieldCurve.AMT_CLOPRI, 0)
            )
        end as AMT_AJUS,
		case
            when B.COD_POSNATURE = 'ReverseRepo' then coalesce(P2.AMT_INDEXPR, P2.AMT_ASSEPR) * b.Qtd_Total
            when B.COD_POSNATURE = 'HeldToMaturity' then coalesce(htm.AMT_INDEXPR, htm.AMT_ASSEPR) * b.Qtd_Total
            else coalesce(POSI.AMT_INDEXPR, POSI.AMT_ASSEPR) * b.Qtd_Total
        end as AMT_BRUTO_GER                                             ,
				0 as AMT_PU_AGIO                                         ,
				(DETCASH.AMT_CAPITAL - A.AMT_ISSUPRICE) as AMT_PU_EMIS_CM,
				PUPar.AMT_CLOPRI as AMT_PU_EMIS_JUROS                    ,
				0 as AMT_PU_EMIS_PRIZE                                   ,
				A.AMT_ISSUPRICE as AMT_PU_EMIS_PRINC                     ,
				DETPRHTM.AMT_YIELDMATURITY as AMT_TIR_CURVA              ,
				left(a.DES_TRAASN, 60) as DES_NME                        ,
				0 as AMT_VENDA_TERMO                                     ,
				0 as AMT_PU_PAR                                          ,
				POSI.DAT_QLIKUPDATE as DAT_QLIKUPDATE                    ,
				'MEG' as COD_SACBBDD                                     ,
				(
		POSI.DAT_VALUAT::TEXT || B.DES_EVTREF::TEXT || 'MEG'
		) as concatenate
			from
				POSI as POSI
			left join P2 as P2 on
				P2.des_owner = POSI.DES_OWNER
				and P2.dat_valuat = POSI.DAT_VALUAT
				and P2.cod_dmasse = POSI.cod_dmasse
				and posi.dat_update = p2.dat_update
			inner join MAX_VALPORCS as MAX_VALPORCS on
				MAX_VALPORCS.dat_update = POSI.DAT_UPDATE
				and MAX_VALPORCS.des_owner = POSI.DES_OWNER
				and MAX_VALPORCS.dat_valuat = POSI.DAT_VALUAT
			inner join (
				select
					cgc.cod_owner                                                                                                                              ,
					cgc.dat_nav                                                                                                                                ,
					cgc.cod_dmasse                                                                                                                             ,
					cgc.des_evtref                                                                                                   Oper                      ,
					cgc.des_origref                                                                                                                            ,
					coalesce(cgc.amt_qty, 0) + coalesce(qtydepledged.amt_qty_Depledged, 0)                                           as Qtd_Livre              ,
					coalesce(qtyPledged.amt_qty_Pledged, 0)                                                                          as           Qtd_Bloqueada,
					coalesce(cgc.amt_qty, 0) + coalesce(qtyPledged.amt_qty_Pledged, 0) + coalesce(qtydepledged.amt_qty_Depledged, 0) as Qtd_Total              ,
					cgc.DES_EVTREF                                                                                                                             ,
					cgc.cod_posnature                                                                                                                          ,
					cgc.DAT_TRADE                                                                                                                              ,
					cgc.AMT_BOOKAM                                                                                                                             ,
					cgc.AMT_TRCOSAMO                                                                                                                           ,
					cgc.AMT_BOOKC
				from
					CGCPositionGroupBy as CGC
				left join (
					select
						coalesce(SUM(amt_qty), 0)                as amt_qty_Depledged,
						--des_mainref             AS des_mainref                     ,
						des_origref                                                  ,
						dat_nav                                                      ,
						cod_owner                                                    ,
						cod_dmasse
					from
						trf_s3.sss_cgc_position_t scpt
					where
						scpt.DAT_POSITION <= scpt.DAT_NAV
						and scpt.DAT_VALIDITY > scpt.DAT_NAV
						and scpt.cod_owner = v_cliente_id
						and scpt.AMT_QTY <> 0
						and scpt.des_evtref like 'DPG%'
					group by
						des_origref  ,
						--des_mainref,
						dat_nav      ,
						cod_owner    ,
						cod_dmasse
		) qtyDepledged on
					qtyDepledged.des_origref = cgc.des_evtref
					and qtyDepledged.dat_nav = cgc.dat_nav
					and qtyDepledged.cod_owner = cgc.cod_owner
					and qtyDepledged.cod_dmasse = cgc.cod_dmasse
				left join (
					select
						coalesce(SUM(scpt.amt_qty), 0) as amt_qty_Pledged,
						scpt.des_origref                                 ,
						scpt.dat_nav                                     ,
						scpt.cod_owner                                   ,
						scpt.cod_dmasse
					from
						trf_s3.sss_cgc_position_t scpt
					where
						scpt.DAT_POSITION <= scpt.DAT_NAV
						and scpt.cod_owner = v_cliente_id
						and scpt.DAT_VALIDITY > scpt.DAT_NAV
						and scpt.cod_posnature = 'Pledged'
						and scpt.amt_qty <> 0
					group by
						scpt.des_origref,
						scpt.dat_nav    ,
						scpt.cod_owner  ,
						scpt.cod_dmasse
		) qtyPledged on
					qtyPledged.des_origref = cgc.des_evtref
					and qtyPledged.dat_nav = cgc.dat_nav
					and qtyPledged.cod_owner = cgc.cod_owner
					and qtyPledged.cod_dmasse = cgc.cod_dmasse
		) as b on
				POSI.DES_OWNER = B.COD_OWNER
				and B.DAT_NAV = POSI.DAT_VALUAT
				and B.COD_DMASSE = POSI.COD_DMASSE
				and B.COD_POSNATURE in ('Settled', 'ReverseRepo', 'HeldToMaturity')
				and b.Qtd_Total > 0
				-- novo filtro
			left join cancelledcuscominst as pos_termo on
				pos_termo.des_appref = b.des_evtref
				and pos_termo.dat_traded <= b.dat_nav
				and pos_termo.dat_theori > b.dat_nav
			inner join trf_s3.SSS_ASSET_T A on
				b.COD_DMASSE = a.COD_DMASSE
				and a.cod_dmasfm in (1, 7)
			left join trf_s3.SSS_ISSUER_T c on
				c.COD_DMISSUER = a.COD_DMISSUER
			left join trf_s3.SSS_CUS_COM_INS_T F on
				F.COD_TRAREF = B.DES_EVTREF
				and F.DES_STATUS in ('SETTLED', 'INSTRUCTED')
			left join trf_s3.SSS_CUS_COM_INS_CD_T CD on
				CD.COD_DMCUCO = F.COD_DMCUCO
				and (
		b.cod_posnature = 'Repo'
					or b.cod_posnature = 'ReverseRepo'
		)
			left join trf_s3.SSS_INTEREST_T d on
				d.COD_DMASSE = a.COD_DMASSE
			left join trf_s3.SSS_REFRATE_T I on
				D.COD_DMRART = I.COD_DMRART
			left join trf_s3.SSS_NATIONAL_CLASS_T e on
				e.COD_DMNATCLAS = a.COD_DMNATCLAS
			left join MAINDETPRDUR as DETPRDUR1 on
			A.COD_DMASSE = DETPRDUR1.COD_DMASSE
			and b.DAT_TRADE = DETPRDUR1.DAT_GENER
			left join MAINDETPRDUR as DETPRDUR2 on
			A.COD_DMASSE = DETPRDUR2.COD_DMASSE
			and b.DAT_NAV = DETPRDUR2.DAT_GENER
			left join DETPRPUPAR on
A.COD_DMASSE = DETPRPUPAR.COD_DMASSE
and b.DAT_TRADE = DETPRPUPAR.DAT_GENER
left JOIN DETPRHTM on
A.COD_DMASSE = DETPRHTM.COD_DMASSE
and b.DAT_TRADE = DETPRHTM.DAT_GENER
			left join DETCASH as DETCASH on
				DETCASH.DAT_GENERATE = b.DAT_TRADE
				and A.COD_TRAAST = DETCASH.COD_TRADASSET
				and DETCASH.DAT_START <= b.DAT_TRADE
				and b.DAT_TRADE < DETCASH.DAT_END
			left join YieldCurve as YieldCurve on
				YieldCurve.DES_OWNER = B.COD_OWNER
				and B.COD_DMASSE = YieldCurve.COD_DMASSE
				and YieldCurve.DAT_VALUAT = B.DAT_NAV
			left join PUPar as PUPar on
				PUPar.DES_OWNER = B.COD_OWNER
				and B.COD_DMASSE = PUPar.COD_DMASSE
				and PUPar.DAT_VALUAT = B.DAT_NAV
			left join POSI_HeldToMaturity htm on
				htm.des_owner = B.cod_OWNER
				and htm.dat_valuat = b.DAT_NAV
				and htm.cod_dmasse = b.cod_dmasse
				and htm.des_contractref = b.des_evtref
				and htm.des_posnat = b.cod_posnature
		) as subquery
		)
		;
    raise notice '% Finalizacion del select',clock_timestamp();
    raise notice '% Iniciando idetificacion de registros unicos',clock_timestamp();
    FOR reco IN SELECT   *
        FROM TEM_meg_cart_pos_rf_t
        WHERE (cod_rfoper,dat_hist) NOT IN (
            SELECT cod_rfoper,dat_hist
            FROM TEM_meg_cart_pos_rf_t
            GROUP BY cod_rfoper,dat_hist
            HAVING COUNT(*) > 1
        ) LOOP
            raise NOTICE '%             Insertando % % %',clock_timestamp(),reco.cod_cli,reco.cod_rfoper,reco.dat_hist;
        END LOOP;
        with cte_unicos AS (
        SELECT *
        FROM TEM_meg_cart_pos_rf_t
        WHERE (dat_hist, cod_rfoper) NOT IN (
            SELECT dat_hist, cod_rfoper
            FROM TEM_meg_cart_pos_rf_t
            GROUP BY dat_hist, cod_rfoper
            HAVING COUNT(*) > 1
        )
    )			
    INSERT INTO trf_s3.cart_pos_rf_t(COD_OPTERMO,COD_INST,AMT_BLOCK_QT,AMT_DAY_ACQUI_MAT                       ,
                AMT_DAY_UTIL_MAT,DAT_HIST,DAT_ACQUI,DAT_EMISS,DAT_MATURITY,DAT_RESG                            ,
                COD_NEG_VENC,COD_INDEX,AMT_TAX_OVER,AMT_DISP_PAP_QT,COD_RF_LASTRO,COD_RFOPER,COD_RF_TYP,COD_MTM,
                AMT_AGIO,AMT_AP,AMT_APLI,AMT_BRUTO_POS                                                         ,
                AMT_CM,AMT_COUPON,AMT_PAP_DUR,AMT_JUROS,AMT_LIQ_POS_IRRF,AMT_PRIZE,AMT_PRINC,AMT_PROV_IOF      ,
                AMT_PROV_IRRF,AMT_PU,AMT_PU_AJUS_MTM,AMT_PU_ACQUI,AMT_PU_CURVA,AMT_PU_MERC,AMT_PU_NOMINAL      ,
                AMT_RESG,AMT_TAX_AA,AMT_TIR,AMT_TIR_MERC,AMT_RESG_OP_COMPR,COD_CLI                             ,
                COD_ORIGEM                                                                                     ,
                AMT_AJUS,AMT_BRUTO_GER,AMT_PU_AGIO ,AMT_PU_EMIS_CM,AMT_PU_EMIS_JUROS,AMT_PU_EMIS_PRIZE         ,
                AMT_PU_EMIS_PRINC,AMT_TIR_CURVA,DES_NME,AMT_VENDA_TERMO,AMT_PU_PAR                             ,
                DAT_QLIKUPDATE,COD_SACBBDD, concatenate)
    (SELECT COD_OPTERMO,COD_INST,AMT_BLOCK_QT,AMT_DAY_ACQUI_MAT                                                ,
                AMT_DAY_UTIL_MAT,DAT_HIST,DAT_ACQUI,DAT_EMISS,DAT_MATURITY,DAT_RESG                            ,
                COD_NEG_VENC,COD_INDEX,AMT_TAX_OVER,AMT_DISP_PAP_QT,COD_RF_LASTRO,COD_RFOPER,COD_RF_TYP,COD_MTM,
                AMT_AGIO,AMT_AP,AMT_APLI,AMT_BRUTO_POS                                                         ,
                AMT_CM,AMT_COUPON,AMT_PAP_DUR,AMT_JUROS,AMT_LIQ_POS_IRRF,AMT_PRIZE,AMT_PRINC,AMT_PROV_IOF      ,
                AMT_PROV_IRRF,AMT_PU,AMT_PU_AJUS_MTM,AMT_PU_ACQUI,AMT_PU_CURVA,AMT_PU_MERC,AMT_PU_NOMINAL      ,
                AMT_RESG,AMT_TAX_AA,AMT_TIR,AMT_TIR_MERC,AMT_RESG_OP_COMPR,COD_CLI                             ,
                COD_ORIGEM                                                                                     ,
                AMT_AJUS,AMT_BRUTO_GER,AMT_PU_AGIO ,AMT_PU_EMIS_CM,AMT_PU_EMIS_JUROS,AMT_PU_EMIS_PRIZE         ,
                AMT_PU_EMIS_PRINC,AMT_TIR_CURVA,DES_NME,AMT_VENDA_TERMO,AMT_PU_PAR                             ,
        DAT_QLIKUPDATE,COD_SACBBDD, concatenate
        FROM cte_unicos)
                ON CONFLICT (dat_hist, cod_rfoper, base_id)
                DO UPDATE SET 
        COD_OPTERMO = excluded.COD_OPTERMO                            ,
                    COD_INST = excluded.COD_INST                      ,
                        AMT_DAY_ACQUI_MAT = excluded.AMT_DAY_ACQUI_MAT,
                        AMT_DAY_UTIL_MAT = excluded.AMT_DAY_UTIL_MAT  ,
                        DAT_ACQUI = excluded.DAT_ACQUI                ,
                        DAT_EMISS = excluded.DAT_EMISS                ,
                        DAT_MATURITY = excluded.DAT_MATURITY          ,
                        DAT_RESG = excluded.DAT_RESG                  ,
                        COD_NEG_VENC = excluded.COD_NEG_VENC          ,
                        COD_INDEX = excluded.COD_INDEX                ,
                        AMT_TAX_OVER = excluded.AMT_TAX_OVER          ,
                        AMT_BLOCK_QT = excluded.AMT_BLOCK_QT          ,
                        AMT_DISP_PAP_QT = excluded.AMT_DISP_PAP_QT    ,
                        COD_RF_TYP = excluded.COD_RF_TYP              ,
                        COD_MTM = excluded.COD_MTM                    ,
                        AMT_AGIO = excluded.AMT_AGIO                  ,
                        AMT_AP = excluded.AMT_AP                      ,
                        AMT_APLI = excluded.AMT_APLI                  ,
                        AMT_BRUTO_POS = excluded.AMT_BRUTO_POS        ,
                        AMT_CM = excluded.AMT_CM                      ,
                        AMT_COUPON = excluded.AMT_COUPON              ,
                        AMT_PAP_DUR = excluded.AMT_PAP_DUR            ,
                        AMT_JUROS = excluded.AMT_JUROS                ,
                        AMT_LIQ_POS_IRRF = excluded.AMT_LIQ_POS_IRRF  ,
                        AMT_PRIZE = excluded.AMT_PRIZE                ,
                        AMT_PRINC = excluded.AMT_PRINC                ,
                        AMT_PROV_IOF = excluded.AMT_PROV_IOF          ,
                        AMT_PROV_IRRF = excluded.AMT_PROV_IRRF        ,
                        AMT_PU = excluded.AMT_PU                      ,
                        AMT_PU_AJUS_MTM = excluded.AMT_PU_AJUS_MTM    ,
                        AMT_PU_ACQUI = excluded.AMT_PU_ACQUI          ,
                        AMT_PU_CURVA = excluded.AMT_PU_CURVA          ,
                        AMT_PU_MERC = excluded.AMT_PU_MERC            ,
                        AMT_PU_NOMINAL = excluded.AMT_PU_NOMINAL      ,
                        AMT_RESG = excluded.AMT_RESG                  ,
                        AMT_TAX_AA = excluded.AMT_TAX_AA              ,
                        AMT_TIR = excluded.AMT_TIR                    ,
                        AMT_TIR_MERC = excluded.AMT_TIR_MERC          ,
                        AMT_RESG_OP_COMPR = excluded.AMT_RESG_OP_COMPR,
                        COD_CLI = excluded.COD_CLI                    ,
                        COD_ORIGEM = excluded.COD_ORIGEM              ,
                        AMT_AJUS = excluded.AMT_AJUS                  ,
                        AMT_BRUTO_GER = excluded.AMT_BRUTO_GER        ,
                        AMT_PU_AGIO = excluded.AMT_PU_AGIO            ,
                        AMT_PU_EMIS_CM = excluded.AMT_PU_EMIS_CM      ,
                        AMT_PU_EMIS_JUROS = excluded.AMT_PU_EMIS_JUROS,
                        AMT_PU_EMIS_PRIZE = excluded.AMT_PU_EMIS_PRIZE,
                        AMT_PU_EMIS_PRINC = excluded.AMT_PU_EMIS_PRINC,
                        AMT_TIR_CURVA = excluded.AMT_TIR_CURVA        ,
                        DES_NME = excluded.DES_NME                    ,
                        AMT_VENDA_TERMO = excluded.AMT_VENDA_TERMO    ,
                        AMT_PU_PAR = excluded.AMT_PU_PAR, 
                        DAT_QLIKUPDATE = excluded.DAT_QLIKUPDATE,
                        CONCATENATE = excluded.CONCATENATE      ,
                        cod_sacbbdd = excluded.cod_sacbbdd
        ;
    raise notice '% Iniciando idetificacion de registros duplicados',clock_timestamp();
    FOR reco IN SELECT   *
        FROM TEM_meg_cart_pos_rf_t
        WHERE (cod_rfoper,dat_hist) IN (
            SELECT cod_rfoper,dat_hist
            FROM TEM_meg_cart_pos_rf_t
            GROUP BY cod_rfoper,dat_hist
            HAVING COUNT(*) > 1
        ) LOOP
    raise notice '%             Duplicado % %',clock_timestamp(),reco.cod_rfoper,reco.dat_hist;
        END LOOP;
    with DuplicatedRecordsCTE AS (
        SELECT *
        FROM TEM_meg_cart_pos_rf_t
        WHERE (dat_hist, cod_rfoper) IN 
        (
            SELECT dat_hist, cod_rfoper
            FROM TEM_meg_cart_pos_rf_t
            GROUP BY dat_hist, cod_rfoper
            HAVING COUNT(*) > 1
        )
    )		
    INSERT INTO trf_s3.cart_pos_rf_t_err(COD_OPTERMO,COD_INST,AMT_BLOCK_QT,AMT_DAY_ACQUI_MAT                               ,
                            AMT_DAY_UTIL_MAT,DAT_HIST,DAT_ACQUI,DAT_EMISS,DAT_MATURITY,DAT_RESG                            ,
                            COD_NEG_VENC,COD_INDEX,AMT_TAX_OVER,AMT_DISP_PAP_QT,COD_RF_LASTRO,COD_RFOPER,COD_RF_TYP,COD_MTM,
                            AMT_AGIO,AMT_AP,AMT_APLI,AMT_BRUTO_POS                                                         ,
                            AMT_CM,AMT_COUPON,AMT_PAP_DUR,AMT_JUROS,AMT_LIQ_POS_IRRF,AMT_PRIZE,AMT_PRINC,AMT_PROV_IOF      ,
                            AMT_PROV_IRRF,AMT_PU,AMT_PU_AJUS_MTM,AMT_PU_ACQUI,AMT_PU_CURVA,AMT_PU_MERC,AMT_PU_NOMINAL      ,
                            AMT_RESG,AMT_TAX_AA,AMT_TIR,AMT_TIR_MERC,AMT_RESG_OP_COMPR,COD_CLI                             ,
                            COD_ORIGEM                                                                                     ,
                            AMT_AJUS,AMT_BRUTO_GER,AMT_PU_AGIO ,AMT_PU_EMIS_CM,AMT_PU_EMIS_JUROS,AMT_PU_EMIS_PRIZE         ,
                            AMT_PU_EMIS_PRINC,AMT_TIR_CURVA,DES_NME,AMT_VENDA_TERMO,AMT_PU_PAR                             ,
                            DAT_QLIKUPDATE,COD_SACBBDD, concatenate)
    SELECT                                                                                                                  COD_OPTERMO,COD_INST,AMT_BLOCK_QT,AMT_DAY_ACQUI_MAT,
                            AMT_DAY_UTIL_MAT,DAT_HIST,DAT_ACQUI,DAT_EMISS,DAT_MATURITY,DAT_RESG                                                                                ,
                            COD_NEG_VENC,COD_INDEX,AMT_TAX_OVER,AMT_DISP_PAP_QT,COD_RF_LASTRO,COD_RFOPER,COD_RF_TYP,COD_MTM                                                    ,
                            AMT_AGIO,AMT_AP,AMT_APLI,AMT_BRUTO_POS                                                                                                             ,
                            AMT_CM,AMT_COUPON,AMT_PAP_DUR,AMT_JUROS,AMT_LIQ_POS_IRRF,AMT_PRIZE,AMT_PRINC,AMT_PROV_IOF                                                          ,
                            AMT_PROV_IRRF,AMT_PU,AMT_PU_AJUS_MTM,AMT_PU_ACQUI,AMT_PU_CURVA,AMT_PU_MERC,AMT_PU_NOMINAL                                                          ,
                            AMT_RESG,AMT_TAX_AA,AMT_TIR,AMT_TIR_MERC,AMT_RESG_OP_COMPR,COD_CLI                                                                                 ,
                            COD_ORIGEM                                                                                                                                         ,
                            AMT_AJUS,AMT_BRUTO_GER,AMT_PU_AGIO                                                              ,AMT_PU_EMIS_CM,AMT_PU_EMIS_JUROS,AMT_PU_EMIS_PRIZE,
                            AMT_PU_EMIS_PRINC,AMT_TIR_CURVA,DES_NME,AMT_VENDA_TERMO,AMT_PU_PAR                                                                                 ,
                            DAT_QLIKUPDATE,COD_SACBBDD,                                                                     concatenate
    FROM DuplicatedRecordsCTE;	
END loop;
    CLOSE c_cursor;
execute 'drop table if exists MAINDETPRDUR';
execute 'drop table if exists cancelledcuscominst';
execute 'drop table if exists filtered_asset';
execute 'drop table if exists TEM_meg_cart_pos_rf_t';
raise notice '% Proceso finalizado',clock_timestamp();
RETURN 'Proceso finalizado'; --Descomentar esta linea
end;
--$$;-- Comentar esta linea
$function$
;
