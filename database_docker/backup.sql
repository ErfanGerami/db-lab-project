--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

-- Started on 2025-05-25 22:07:40

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 261 (class 1255 OID 240465)
-- Name: get_contest_results(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_contest_results(contest_id integer) RETURNS TABLE(username text, solved_count integer, total_elapsed_seconds bigint, rank integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH solved AS (
        SELECT
            u.username,
            COUNT(co.code_id) AS solved_count,
            COALESCE(SUM(EXTRACT(EPOCH FROM (co.submission_time - con.start_time)))::BIGINT, 0) AS total_elapsed_seconds
        FROM "User" u
        JOIN Contest_User us
            ON u.username = us.user_id AND us.contest_id = contest_id
        JOIN Contest con
            ON con.contest_id = us.contest_id
        LEFT JOIN Problem pr
            ON pr.contest_id = con.contest_id
        LEFT JOIN Code co
            ON co.user_id = u.username
            AND co.problem_id = pr.problem_id
            AND co.accepted
            AND co.submission_time <= con.end_time
            AND co.submission_time = (
                SELECT MAX(co2.submission_time)
                FROM Code co2
                WHERE
                    co2.accepted
                    AND co2.contest_id = co.contest_id
                    AND co2.user_id = u.username
                    AND co2.problem_id = co.problem_id
            )
        GROUP BY u.username
    )
    SELECT
        username,
        solved_count,
        total_elapsed_seconds,
        RANK() OVER (
            ORDER BY solved_count DESC, total_elapsed_seconds ASC
        ) AS rank
    FROM solved;
END;
$$;


ALTER FUNCTION public.get_contest_results(contest_id integer) OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 240463)
-- Name: get_contest_scoreboard(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_contest_scoreboard(contest_id_input integer) RETURNS TABLE(username text, accepted_count integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.username,
        COUNT(co.code_id) AS accepted_count
    FROM "User" u
    JOIN Contest_User us ON u.username = us.user_id AND us.contest_id = contest_id_input
    JOIN Contest con ON con.contest_id = us.contest_id
    LEFT JOIN Code co ON 
        co.user_id = u.username 
        AND co.submission_time <= con.end_time 
        AND co.accepted
        AND co.submission_time = (
            SELECT MAX(co2.submission_time)
            FROM Code co2
            WHERE 
                co2.accepted 
                AND co2.contest_id = co.contest_id 
                AND co2.user_id = u.username 
                AND co2.problem_id = co.problem_id
        )
    GROUP BY u.username;
END;
$$;


ALTER FUNCTION public.get_contest_scoreboard(contest_id_input integer) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 240466)
-- Name: getscoreboard(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.getscoreboard(contest_id integer) RETURNS TABLE(rank integer, username text, "time" integer, solved integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        RANK() OVER (ORDER BY COUNT(*) DESC, SUM(EXTRACT(EPOCH FROM (code.submission_time - co.start_time))) ASC) AS rank,
        us.username,
        SUM(EXTRACT(EPOCH FROM (code.submission_time - co.start_time)))::INT AS time,
        COUNT(*) AS solved
    FROM
        "User" us
        JOIN Contest_User cu ON us.username = cu.user_id
        JOIN Contest co ON cu.contest_id = co.contest_id
        JOIN Problem prob ON prob.contest_id = co.contest_id
        JOIN Code code ON code.problem_id = prob.problem_id AND code.user_id = us.username
    WHERE
        code.accepted = TRUE
        AND code.submission_time = (
            SELECT MAX(code2.submission_time)
            FROM Code code2
            WHERE
                code2.accepted = TRUE
                AND code2.contest_id = co.contest_id
                AND code2.user_id = us.username
                AND code2.problem_id = code.problem_id
        )
        AND co.contest_id = contest_id
    GROUP BY us.username
    ORDER BY solved DESC, time ASC;
END;
$$;


ALTER FUNCTION public.getscoreboard(contest_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 215 (class 1259 OID 240154)
-- Name: User; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."User" (
    username character varying(255) NOT NULL,
    password character varying(255) NOT NULL,
    last_submition date,
    email character varying(255)
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 240185)
-- Name: admin_contest; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admin_contest (
    contest_id integer NOT NULL,
    user_id character varying(255) NOT NULL
);


ALTER TABLE public.admin_contest OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 240322)
-- Name: auth_group; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO erfang;

--
-- TOC entry 236 (class 1259 OID 240321)
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 240330)
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO erfang;

--
-- TOC entry 238 (class 1259 OID 240329)
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 235 (class 1259 OID 240316)
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO erfang;

--
-- TOC entry 234 (class 1259 OID 240315)
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 241 (class 1259 OID 240336)
-- Name: auth_user; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE public.auth_user OWNER TO erfang;

--
-- TOC entry 243 (class 1259 OID 240344)
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.auth_user_groups (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.auth_user_groups OWNER TO erfang;

--
-- TOC entry 242 (class 1259 OID 240343)
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.auth_user_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 240 (class 1259 OID 240335)
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.auth_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 245 (class 1259 OID 240350)
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.auth_user_user_permissions (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_user_user_permissions OWNER TO erfang;

--
-- TOC entry 244 (class 1259 OID 240349)
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.auth_user_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 223 (class 1259 OID 240208)
-- Name: code; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.code (
    code_id integer NOT NULL,
    submission_time timestamp without time zone NOT NULL,
    problem_id integer NOT NULL,
    user_id character varying(255) NOT NULL,
    accepted boolean,
    path character varying(500) NOT NULL,
    status character varying(50)
);


ALTER TABLE public.code OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 240207)
-- Name: code_code_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.code_code_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.code_code_id_seq OWNER TO postgres;

--
-- TOC entry 5078 (class 0 OID 0)
-- Dependencies: 222
-- Name: code_code_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.code_code_id_seq OWNED BY public.code.code_id;


--
-- TOC entry 217 (class 1259 OID 240162)
-- Name: contest; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contest (
    contest_id integer NOT NULL,
    name character varying(500) NOT NULL,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone NOT NULL
);


ALTER TABLE public.contest OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 240161)
-- Name: contest_contest_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.contest_contest_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contest_contest_id_seq OWNER TO postgres;

--
-- TOC entry 5081 (class 0 OID 0)
-- Dependencies: 216
-- Name: contest_contest_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.contest_contest_id_seq OWNED BY public.contest.contest_id;


--
-- TOC entry 229 (class 1259 OID 240277)
-- Name: contest_problem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contest_problem (
    contest_id integer NOT NULL,
    problem_id integer NOT NULL,
    number integer NOT NULL
);


ALTER TABLE public.contest_problem OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 240170)
-- Name: contest_user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contest_user (
    contest_id integer NOT NULL,
    user_id character varying(255) NOT NULL,
    "time" timestamp without time zone
);


ALTER TABLE public.contest_user OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 240408)
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE public.django_admin_log OWNER TO erfang;

--
-- TOC entry 246 (class 1259 OID 240407)
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 233 (class 1259 OID 240308)
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO erfang;

--
-- TOC entry 232 (class 1259 OID 240307)
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 231 (class 1259 OID 240300)
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE public.django_migrations OWNER TO erfang;

--
-- TOC entry 230 (class 1259 OID 240299)
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: erfang
--

ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 248 (class 1259 OID 240436)
-- Name: django_session; Type: TABLE; Schema: public; Owner: erfang
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO erfang;

--
-- TOC entry 221 (class 1259 OID 240201)
-- Name: problem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.problem (
    problem_id integer NOT NULL,
    name character varying(255),
    public_private boolean NOT NULL,
    rating integer,
    text text,
    contest_id integer
);


ALTER TABLE public.problem OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 240200)
-- Name: problem_problem_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.problem_problem_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.problem_problem_id_seq OWNER TO postgres;

--
-- TOC entry 5086 (class 0 OID 0)
-- Dependencies: 220
-- Name: problem_problem_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.problem_problem_id_seq OWNED BY public.problem.problem_id;


--
-- TOC entry 224 (class 1259 OID 240231)
-- Name: tag; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tag (
    name character varying(255) NOT NULL
);


ALTER TABLE public.tag OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 240236)
-- Name: tag_problem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tag_problem (
    tag_id character varying(255) NOT NULL,
    problem_id integer NOT NULL
);


ALTER TABLE public.tag_problem OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 240264)
-- Name: testcase; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.testcase (
    testcase_id integer NOT NULL,
    input_file character varying(500) NOT NULL,
    output_file character varying(500) NOT NULL,
    problem_id integer NOT NULL
);


ALTER TABLE public.testcase OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 240263)
-- Name: testcase_testcase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.testcase_testcase_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.testcase_testcase_id_seq OWNER TO postgres;

--
-- TOC entry 5091 (class 0 OID 0)
-- Dependencies: 227
-- Name: testcase_testcase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.testcase_testcase_id_seq OWNED BY public.testcase.testcase_id;


--
-- TOC entry 226 (class 1259 OID 240251)
-- Name: toturial; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.toturial (
    problem_id integer NOT NULL,
    text character varying(500) NOT NULL,
    file character varying(500)
);


ALTER TABLE public.toturial OWNER TO postgres;

--
-- TOC entry 4789 (class 2604 OID 240211)
-- Name: code code_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.code ALTER COLUMN code_id SET DEFAULT nextval('public.code_code_id_seq'::regclass);


--
-- TOC entry 4787 (class 2604 OID 240165)
-- Name: contest contest_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest ALTER COLUMN contest_id SET DEFAULT nextval('public.contest_contest_id_seq'::regclass);


--
-- TOC entry 4788 (class 2604 OID 240204)
-- Name: problem problem_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.problem ALTER COLUMN problem_id SET DEFAULT nextval('public.problem_problem_id_seq'::regclass);


--
-- TOC entry 4790 (class 2604 OID 240267)
-- Name: testcase testcase_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.testcase ALTER COLUMN testcase_id SET DEFAULT nextval('public.testcase_testcase_id_seq'::regclass);


--
-- TOC entry 5032 (class 0 OID 240154)
-- Dependencies: 215
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."User" (username, password, last_submition, email) FROM stdin;
alice	hashedpassword1	2025-05-01	\N
bob	hashedpassword2	2025-05-03	\N
charlie	hashedpassword3	\N	\N
erfang1	5637749740820746543	\N	\N
erfang2	3487813621186016997	\N	\N
erfang3	-4753394739665398688	\N	\N
erfan	-7174361340039200272	\N	\N
erfan12	-6080221316730465364	\N	\N
erfan123	6450002222872142146	\N	\N
erfan1234	1	\N	\N
e	6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b	\N	\N
123	a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3	\N	\N
\.


--
-- TOC entry 5036 (class 0 OID 240185)
-- Dependencies: 219
-- Data for Name: admin_contest; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admin_contest (contest_id, user_id) FROM stdin;
1	alice
2	bob
3	e
3	erfang1
\.


--
-- TOC entry 5054 (class 0 OID 240322)
-- Dependencies: 237
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.auth_group (id, name) FROM stdin;
\.


--
-- TOC entry 5056 (class 0 OID 240330)
-- Dependencies: 239
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- TOC entry 5052 (class 0 OID 240316)
-- Dependencies: 235
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add log entry	1	add_logentry
2	Can change log entry	1	change_logentry
3	Can delete log entry	1	delete_logentry
4	Can view log entry	1	view_logentry
5	Can add permission	2	add_permission
6	Can change permission	2	change_permission
7	Can delete permission	2	delete_permission
8	Can view permission	2	view_permission
9	Can add group	3	add_group
10	Can change group	3	change_group
11	Can delete group	3	delete_group
12	Can view group	3	view_group
13	Can add user	4	add_user
14	Can change user	4	change_user
15	Can delete user	4	delete_user
16	Can view user	4	view_user
17	Can add content type	5	add_contenttype
18	Can change content type	5	change_contenttype
19	Can delete content type	5	delete_contenttype
20	Can view content type	5	view_contenttype
21	Can add session	6	add_session
22	Can change session	6	change_session
23	Can delete session	6	delete_session
24	Can view session	6	view_session
\.


--
-- TOC entry 5058 (class 0 OID 240336)
-- Dependencies: 241
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
\.


--
-- TOC entry 5060 (class 0 OID 240344)
-- Dependencies: 243
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- TOC entry 5062 (class 0 OID 240350)
-- Dependencies: 245
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- TOC entry 5040 (class 0 OID 240208)
-- Dependencies: 223
-- Data for Name: code; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.code (code_id, submission_time, problem_id, user_id, accepted, path, status) FROM stdin;
2	2025-05-10 10:20:00	2	bob	f	submissions/bob_binary.cpp	\N
3	2025-06-15 12:30:00	3	charlie	t	submissions/charlie_dp.cpp	\N
8	2025-05-16 08:00:55.735399	3	e	\N	uploads/submissions/32a9690a7f8647d6a8141659ae757480.cpp	\N
9	2025-05-16 08:01:40.568576	3	e	\N	uploads/submissions/e/dc38138515724e19a7bc601f194ea05c.cpp	\N
34	2025-05-21 21:34:20.251145	34	e	f	submissions/e/28cfc7ea60fe4ff1a0b497f71a282fdd.cpp	wrong answer
1	2025-05-10 10:15:00	1	alice	t	uploads/submissions/e/1.cpp	\N
10	2025-05-16 19:19:56.780923	32	e	\N	uploads/submissions/e/d91b115ca381460d88b97d4fa3f7ce37.cpp	\N
11	2025-05-16 19:21:41.846851	32	e	t	uploads/submissions/e/27a968ac0a114b07ab41bd98b2a66311.cpp	\N
12	2025-05-16 19:22:28.2547	32	e	f	uploads/submissions/e/d25a8561aa0e4110bea33d0daf74735d.cpp	\N
13	2025-05-21 20:29:22.075774	32	e	\N	uploads/submissions/e/6c68a2e1da9444a6ba64b50d09c1c2de.cpp	\N
14	2025-05-21 20:36:25.213221	32	e	\N	uploads/submissions/e/a402694e134447cf9382ea4920973926.cpp	\N
15	2025-05-21 20:37:38.293374	32	e	\N	uploads/submissions/e/e9ed93ac14074bd99818da10dd94d485.cpp	\N
16	2025-05-21 20:40:28.881962	32	e	\N	uploads/submissions/e/41804ec48b84484586883a3712d0f2a2.cpp	\N
17	2025-05-21 20:41:48.946851	32	e	f	uploads/submissions/e/a53165d9e57747e2a402c92f4c6ea69f.cpp	pending
18	2025-05-21 20:43:59.971636	32	e	f	uploads/submissions/e/dbcc3c75df0d4e429ec609a0986e5ffa.cpp	pending
19	2025-05-21 20:46:03.995815	32	e	f	uploads/submissions/e/4d16301cf13f47ab9f0c75719d8552f1.cpp	pending
20	2025-05-21 20:59:27.56031	32	e	f	uploads/submissions/e/16a94d798b5246b48d5544d961167f5d.cpp	pending
21	2025-05-21 21:00:23.294077	32	e	f	uploads/submissions/e/d8b0539f26fd46929bc8f849a622e6ff.cpp	pending
22	2025-05-21 21:03:14.337818	32	e	f	submissions/e/09248c3a8a124e4b9179ddbb536a15c8.cpp	pending
23	2025-05-21 21:05:34.475607	32	e	f	submissions/e/b1b8642e3a0146989c47082b85eb311d.cpp	pending
24	2025-05-21 21:09:54.818669	33	e	f	submissions/e/b5ab066a1462404396967f018562986d.cpp	pending
25	2025-05-21 21:12:57.793302	33	e	f	submissions/e/b08001345b8545fe842eb65f293d3530.cpp	pending
26	2025-05-21 21:14:17.813869	33	e	f	submissions/e/cf4dd6cf8ed448deab412aba76c94c58.cpp	pending
27	2025-05-21 21:15:11.3374	33	e	f	submissions/e/04526fd88358419ab0ff3ccaf775d5e1.cpp	pending
28	2025-05-21 21:16:15.469664	33	e	f	submissions/e/78527af82df6455aad73e831188211d6.cpp	pending
35	2025-05-21 21:34:39.015832	34	e	f	submissions/e/1ab1155e73614d74a1502b92f57363f4.cpp	wrong answer
29	2025-05-21 21:17:07.176843	33	e	f	submissions/e/d62b6b8dbd524b91966701f7fd9d5c9a.cpp	pending
30	2025-05-21 21:17:46.088266	33	e	f	submissions/e/9d507b5d1e6f41f6b89be945c983b4de.cpp	pending
31	2025-05-21 21:31:02.175038	34	e	f	submissions/e/1557b66654df4c5d91f6f16762759191.cpp	pending
36	2025-05-21 21:57:10.094463	34	e	f	submissions/e/97cfbf8481614e659a6a43c6263adad7.cpp	wrong answer
32	2025-05-21 21:33:19.711694	34	e	f	submissions/e/024e7bf1384d430b9d316fdb97aa9f7e.cpp	wrong answer
33	2025-05-21 21:33:51.555083	34	e	t	submissions/e/e4a6b93ee977443ebf7e27cd6946aec4.cpp	accepted
37	2025-05-21 21:58:40.710983	34	e	t	submissions/e/b6645926a740449a89aea1bd58afe3b2.cpp	accepted
\.


--
-- TOC entry 5034 (class 0 OID 240162)
-- Dependencies: 217
-- Data for Name: contest; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contest (contest_id, name, start_time, end_time) FROM stdin;
1	Spring Challenge	2025-05-10 10:00:00	2025-05-10 14:00:00
2	Summer Challenge	2025-06-15 12:00:00	2025-06-15 16:00:00
3	wdwd	2025-05-08 04:43:00	2025-06-05 04:43:00
\.


--
-- TOC entry 5046 (class 0 OID 240277)
-- Dependencies: 229
-- Data for Name: contest_problem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contest_problem (contest_id, problem_id, number) FROM stdin;
1	1	1
1	2	2
2	3	1
\.


--
-- TOC entry 5035 (class 0 OID 240170)
-- Dependencies: 218
-- Data for Name: contest_user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contest_user (contest_id, user_id, "time") FROM stdin;
1	alice	2025-05-10 10:01:00
1	bob	2025-05-10 10:05:00
2	charlie	2025-06-15 12:10:00
2	e	\N
\.


--
-- TOC entry 5064 (class 0 OID 240408)
-- Dependencies: 247
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- TOC entry 5050 (class 0 OID 240308)
-- Dependencies: 233
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.django_content_type (id, app_label, model) FROM stdin;
1	admin	logentry
2	auth	permission
3	auth	group
4	auth	user
5	contenttypes	contenttype
6	sessions	session
\.


--
-- TOC entry 5048 (class 0 OID 240300)
-- Dependencies: 231
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2025-05-15 01:38:38.909069+03:30
2	auth	0001_initial	2025-05-15 01:38:38.97436+03:30
3	admin	0001_initial	2025-05-15 01:38:38.990063+03:30
4	admin	0002_logentry_remove_auto_add	2025-05-15 01:38:39.008922+03:30
5	admin	0003_logentry_add_action_flag_choices	2025-05-15 01:38:39.011573+03:30
6	contenttypes	0002_remove_content_type_name	2025-05-15 01:38:39.023553+03:30
7	auth	0002_alter_permission_name_max_length	2025-05-15 01:38:39.030062+03:30
8	auth	0003_alter_user_email_max_length	2025-05-15 01:38:39.035443+03:30
9	auth	0004_alter_user_username_opts	2025-05-15 01:38:39.036879+03:30
10	auth	0005_alter_user_last_login_null	2025-05-15 01:38:39.046208+03:30
11	auth	0006_require_contenttypes_0002	2025-05-15 01:38:39.048218+03:30
12	auth	0007_alter_validators_add_error_messages	2025-05-15 01:38:39.053208+03:30
13	auth	0008_alter_user_username_max_length	2025-05-15 01:38:39.057529+03:30
14	auth	0009_alter_user_last_name_max_length	2025-05-15 01:38:39.068722+03:30
15	auth	0010_alter_group_name_max_length	2025-05-15 01:38:39.071149+03:30
16	auth	0011_update_proxy_permissions	2025-05-15 01:38:39.080986+03:30
17	auth	0012_alter_user_first_name_max_length	2025-05-15 01:38:39.085331+03:30
18	sessions	0001_initial	2025-05-15 01:38:39.099176+03:30
\.


--
-- TOC entry 5065 (class 0 OID 240436)
-- Dependencies: 248
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: erfang
--

COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- TOC entry 5038 (class 0 OID 240201)
-- Dependencies: 221
-- Data for Name: problem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.problem (problem_id, name, public_private, rating, text, contest_id) FROM stdin;
2	Binary Search	t	1200	wedewdewd\ndwefewfewf\newf\newfew\n	1
3	Dynamic Programming Intro	f	1600	\N	2
1	FizzBuzz	t	800	## sdewdew\newdewdewd\n\n```\ne2ded12\n```\n	1
5	ewdewde	t	1212	wdwd	\N
6	ewdewde	t	1212	wdwd	\N
7	ewdewde	t	1212	wdwd	\N
8	ewdewde	t	1212	wdwd	\N
9	ewdewde	t	1212	wdwd	\N
10	ewdewde	t	1212	wdwd	\N
11	ewdewde	t	1212	wdwd	\N
12	ewdewde	t	1212	wdwd	\N
23	123321	t	1231	qdwd	3
30	qwswq112	t	12121	123123	3
31	12w2	t	1322312	1231231	3
32	test	t	1	wedewdewdewd	3
33	main	t	76	wqefdwqfwq	3
34	main2	f	212	qwdqw	3
\.


--
-- TOC entry 5041 (class 0 OID 240231)
-- Dependencies: 224
-- Data for Name: tag; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tag (name) FROM stdin;
Math
Greedy
Dynamic Programming
\.


--
-- TOC entry 5042 (class 0 OID 240236)
-- Dependencies: 225
-- Data for Name: tag_problem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tag_problem (tag_id, problem_id) FROM stdin;
Math	1
Greedy	2
Dynamic Programming	3
Greedy	1
Greedy	23
Greedy	30
Dynamic Programming	31
Math	32
Dynamic Programming	33
\.


--
-- TOC entry 5045 (class 0 OID 240264)
-- Dependencies: 228
-- Data for Name: testcase; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.testcase (testcase_id, input_file, output_file, problem_id) FROM stdin;
2	inputs/binary_1.in	outputs/binary_1.out	2
3	inputs/dp_1.in	outputs/dp_1.out	3
4	uploads/test_cases/f21322a54a9c45ce8c64b514bec7ab65.cpp	uploads/test_cases/c416fd538e0f4a00a0fce315cc2a9284.cpp	30
5	uploads/test_cases/b644c5f21e5e4ca3adb9414091b765c4.cpp	uploads/test_cases/3e735e193e2d4551bd4a6afcf990f81b.cpp	30
6	uploads/test_cases/75a2c786395f4356ad0e51e00f72ae32.cpp	uploads/test_cases/0cdddb92f6f84d548868d9e981105ffa.cpp	31
7	uploads/test_cases/06a265e2697e4728aa5e0cb5ca5e2f5c.cpp	uploads/test_cases/ac499b04cf8b4be797265a24dff28d54.cpp	31
1	uploads/test_cases/1.txt	uploads/test_cases/1out.txt	1
8	uploads/test_cases/03373be29d874d64b1edf2679ba10691.txt	uploads/test_cases/c783efe69cfa407e9833fa13305b2c0e.txt	32
9	uploads/test_cases/d9288665a0f14a879fcb5e9a8adf0bbd.txt	uploads/test_cases/45a298450d6d4374a492d034ffd5be15.txt	32
10	uploads/test_cases/61b3c9ca9a894e2fad5d288f416cbd2b.txt	uploads/test_cases/dc162dbfa08c420ebd818d141b6183a0.txt	33
11	uploads/test_cases/ccd47fd90c61427fbbe89595cd90850a.txt	uploads/test_cases/92834127866741e086095fcaacc869b7.txt	33
12	test_cases/d665a1936ad248eeb6454632d8dc089b.txt	test_cases/34cb0d455add44dd96d8cced20841b65.txt	34
\.


--
-- TOC entry 5043 (class 0 OID 240251)
-- Dependencies: 226
-- Data for Name: toturial; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.toturial (problem_id, text, file) FROM stdin;
2	Binary search tutorial.	\N
3	DP problem explanation.	tutorials/dp_intro.docx
1	Use modulo for FizzBuzz.\nwdewde\newdewdew\newdewd	tutorials/fizzbuzz.pdf
23	qdwd	uploads/tutorials/c57b679c0cd3438da968e72a4092a5ad.cpp
30	wdwdwqd	\N
31	qdwqdwqdw	\N
32	wdwqdwdwdwdwqd	\N
33	## qwdqwdqwdwdewwfwef	\N
34	#wdefewfe	uploads/tutorials/27e2d670bb074763b895266f8688968b.cpp
\.


--
-- TOC entry 5094 (class 0 OID 0)
-- Dependencies: 236
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);


--
-- TOC entry 5095 (class 0 OID 0)
-- Dependencies: 238
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);


--
-- TOC entry 5096 (class 0 OID 0)
-- Dependencies: 234
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.auth_permission_id_seq', 24, true);


--
-- TOC entry 5097 (class 0 OID 0)
-- Dependencies: 242
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.auth_user_groups_id_seq', 1, false);


--
-- TOC entry 5098 (class 0 OID 0)
-- Dependencies: 240
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.auth_user_id_seq', 1, false);


--
-- TOC entry 5099 (class 0 OID 0)
-- Dependencies: 244
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.auth_user_user_permissions_id_seq', 1, false);


--
-- TOC entry 5100 (class 0 OID 0)
-- Dependencies: 222
-- Name: code_code_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.code_code_id_seq', 37, true);


--
-- TOC entry 5101 (class 0 OID 0)
-- Dependencies: 216
-- Name: contest_contest_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contest_contest_id_seq', 3, true);


--
-- TOC entry 5102 (class 0 OID 0)
-- Dependencies: 246
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);


--
-- TOC entry 5103 (class 0 OID 0)
-- Dependencies: 232
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.django_content_type_id_seq', 6, true);


--
-- TOC entry 5104 (class 0 OID 0)
-- Dependencies: 230
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: erfang
--

SELECT pg_catalog.setval('public.django_migrations_id_seq', 18, true);


--
-- TOC entry 5105 (class 0 OID 0)
-- Dependencies: 220
-- Name: problem_problem_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.problem_problem_id_seq', 34, true);


--
-- TOC entry 5106 (class 0 OID 0)
-- Dependencies: 227
-- Name: testcase_testcase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.testcase_testcase_id_seq', 12, true);


--
-- TOC entry 4793 (class 2606 OID 240160)
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (username);


--
-- TOC entry 4801 (class 2606 OID 240189)
-- Name: admin_contest admin_contest_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_contest
    ADD CONSTRAINT admin_contest_pkey PRIMARY KEY (contest_id, user_id);


--
-- TOC entry 4833 (class 2606 OID 240434)
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- TOC entry 4838 (class 2606 OID 240365)
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- TOC entry 4841 (class 2606 OID 240334)
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 4835 (class 2606 OID 240326)
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- TOC entry 4828 (class 2606 OID 240356)
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- TOC entry 4830 (class 2606 OID 240320)
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- TOC entry 4849 (class 2606 OID 240348)
-- Name: auth_user_groups auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 4852 (class 2606 OID 240380)
-- Name: auth_user_groups auth_user_groups_user_id_group_id_94350c0c_uniq; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_94350c0c_uniq UNIQUE (user_id, group_id);


--
-- TOC entry 4843 (class 2606 OID 240340)
-- Name: auth_user auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- TOC entry 4855 (class 2606 OID 240354)
-- Name: auth_user_user_permissions auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- TOC entry 4858 (class 2606 OID 240394)
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_permission_id_14a6b632_uniq; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_14a6b632_uniq UNIQUE (user_id, permission_id);


--
-- TOC entry 4846 (class 2606 OID 240429)
-- Name: auth_user auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- TOC entry 4807 (class 2606 OID 240215)
-- Name: code code_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.code
    ADD CONSTRAINT code_pkey PRIMARY KEY (code_id);


--
-- TOC entry 4795 (class 2606 OID 240169)
-- Name: contest contest_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest
    ADD CONSTRAINT contest_pkey PRIMARY KEY (contest_id);


--
-- TOC entry 4817 (class 2606 OID 240283)
-- Name: contest_problem contest_problem_contest_id_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_problem
    ADD CONSTRAINT contest_problem_contest_id_number_key UNIQUE (contest_id, number);


--
-- TOC entry 4819 (class 2606 OID 240281)
-- Name: contest_problem contest_problem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_problem
    ADD CONSTRAINT contest_problem_pkey PRIMARY KEY (contest_id, problem_id, number);


--
-- TOC entry 4799 (class 2606 OID 240174)
-- Name: contest_user contest_user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_user
    ADD CONSTRAINT contest_user_pkey PRIMARY KEY (contest_id, user_id);


--
-- TOC entry 4861 (class 2606 OID 240415)
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- TOC entry 4823 (class 2606 OID 240314)
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- TOC entry 4825 (class 2606 OID 240312)
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- TOC entry 4821 (class 2606 OID 240306)
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- TOC entry 4865 (class 2606 OID 240442)
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- TOC entry 4803 (class 2606 OID 240206)
-- Name: problem problem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.problem
    ADD CONSTRAINT problem_pkey PRIMARY KEY (problem_id);


--
-- TOC entry 4809 (class 2606 OID 240235)
-- Name: tag tag_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (name);


--
-- TOC entry 4811 (class 2606 OID 240240)
-- Name: tag_problem tag_problem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tag_problem
    ADD CONSTRAINT tag_problem_pkey PRIMARY KEY (tag_id, problem_id);


--
-- TOC entry 4815 (class 2606 OID 240271)
-- Name: testcase testcase_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.testcase
    ADD CONSTRAINT testcase_pkey PRIMARY KEY (testcase_id);


--
-- TOC entry 4813 (class 2606 OID 240257)
-- Name: toturial tutorial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toturial
    ADD CONSTRAINT tutorial_pkey PRIMARY KEY (problem_id);


--
-- TOC entry 4797 (class 2606 OID 248911)
-- Name: contest unique_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest
    ADD CONSTRAINT unique_name UNIQUE (name);


--
-- TOC entry 4805 (class 2606 OID 248919)
-- Name: problem unique_problem_contest; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.problem
    ADD CONSTRAINT unique_problem_contest UNIQUE (name, contest_id);


--
-- TOC entry 4831 (class 1259 OID 240435)
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- TOC entry 4836 (class 1259 OID 240376)
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- TOC entry 4839 (class 1259 OID 240377)
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- TOC entry 4826 (class 1259 OID 240362)
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- TOC entry 4847 (class 1259 OID 240392)
-- Name: auth_user_groups_group_id_97559544; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_user_groups_group_id_97559544 ON public.auth_user_groups USING btree (group_id);


--
-- TOC entry 4850 (class 1259 OID 240391)
-- Name: auth_user_groups_user_id_6a12ed8b; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_user_groups_user_id_6a12ed8b ON public.auth_user_groups USING btree (user_id);


--
-- TOC entry 4853 (class 1259 OID 240406)
-- Name: auth_user_user_permissions_permission_id_1fbb5f2c; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_user_user_permissions_permission_id_1fbb5f2c ON public.auth_user_user_permissions USING btree (permission_id);


--
-- TOC entry 4856 (class 1259 OID 240405)
-- Name: auth_user_user_permissions_user_id_a95ead1b; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_user_user_permissions_user_id_a95ead1b ON public.auth_user_user_permissions USING btree (user_id);


--
-- TOC entry 4844 (class 1259 OID 240430)
-- Name: auth_user_username_6821ab7c_like; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX auth_user_username_6821ab7c_like ON public.auth_user USING btree (username varchar_pattern_ops);


--
-- TOC entry 4859 (class 1259 OID 240426)
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- TOC entry 4862 (class 1259 OID 240427)
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- TOC entry 4863 (class 1259 OID 240444)
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- TOC entry 4866 (class 1259 OID 240443)
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: erfang
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- TOC entry 4869 (class 2606 OID 240190)
-- Name: admin_contest admin_contest_contest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_contest
    ADD CONSTRAINT admin_contest_contest_id_fkey FOREIGN KEY (contest_id) REFERENCES public.contest(contest_id);


--
-- TOC entry 4870 (class 2606 OID 240195)
-- Name: admin_contest admin_contest_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin_contest
    ADD CONSTRAINT admin_contest_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."User"(username);


--
-- TOC entry 4881 (class 2606 OID 240371)
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4882 (class 2606 OID 240366)
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4880 (class 2606 OID 240357)
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4883 (class 2606 OID 240386)
-- Name: auth_user_groups auth_user_groups_group_id_97559544_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_97559544_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4884 (class 2606 OID 240381)
-- Name: auth_user_groups auth_user_groups_user_id_6a12ed8b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_6a12ed8b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4885 (class 2606 OID 240400)
-- Name: auth_user_user_permissions auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permi_permission_id_1fbb5f2c_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4886 (class 2606 OID 240395)
-- Name: auth_user_user_permissions auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_a95ead1b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4872 (class 2606 OID 240221)
-- Name: code code_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.code
    ADD CONSTRAINT code_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES public.problem(problem_id);


--
-- TOC entry 4873 (class 2606 OID 240226)
-- Name: code code_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.code
    ADD CONSTRAINT code_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."User"(username);


--
-- TOC entry 4878 (class 2606 OID 240284)
-- Name: contest_problem contest_problem_contest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_problem
    ADD CONSTRAINT contest_problem_contest_id_fkey FOREIGN KEY (contest_id) REFERENCES public.contest(contest_id);


--
-- TOC entry 4879 (class 2606 OID 240289)
-- Name: contest_problem contest_problem_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_problem
    ADD CONSTRAINT contest_problem_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES public.problem(problem_id);


--
-- TOC entry 4867 (class 2606 OID 240175)
-- Name: contest_user contest_user_contest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_user
    ADD CONSTRAINT contest_user_contest_id_fkey FOREIGN KEY (contest_id) REFERENCES public.contest(contest_id);


--
-- TOC entry 4868 (class 2606 OID 240180)
-- Name: contest_user contest_user_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contest_user
    ADD CONSTRAINT contest_user_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."User"(username);


--
-- TOC entry 4887 (class 2606 OID 240416)
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4888 (class 2606 OID 240421)
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: erfang
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES public.auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 4871 (class 2606 OID 240448)
-- Name: problem fk_problem_contest; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.problem
    ADD CONSTRAINT fk_problem_contest FOREIGN KEY (contest_id) REFERENCES public.contest(contest_id);


--
-- TOC entry 4874 (class 2606 OID 240458)
-- Name: tag_problem tag_problem_problem_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tag_problem
    ADD CONSTRAINT tag_problem_problem_fk FOREIGN KEY (problem_id) REFERENCES public.problem(problem_id) ON DELETE CASCADE;


--
-- TOC entry 4875 (class 2606 OID 240453)
-- Name: tag_problem tag_problem_tag_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tag_problem
    ADD CONSTRAINT tag_problem_tag_fk FOREIGN KEY (tag_id) REFERENCES public.tag(name) ON DELETE CASCADE;


--
-- TOC entry 4877 (class 2606 OID 240272)
-- Name: testcase testcase_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.testcase
    ADD CONSTRAINT testcase_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES public.problem(problem_id);


--
-- TOC entry 4876 (class 2606 OID 240258)
-- Name: toturial tutorial_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.toturial
    ADD CONSTRAINT tutorial_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES public.problem(problem_id);


--
-- TOC entry 5071 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO erfang;


--
-- TOC entry 5072 (class 0 OID 0)
-- Dependencies: 261
-- Name: FUNCTION get_contest_results(contest_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_contest_results(contest_id integer) TO erfang;


--
-- TOC entry 5073 (class 0 OID 0)
-- Dependencies: 249
-- Name: FUNCTION get_contest_scoreboard(contest_id_input integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_contest_scoreboard(contest_id_input integer) TO erfang;


--
-- TOC entry 5074 (class 0 OID 0)
-- Dependencies: 262
-- Name: FUNCTION getscoreboard(contest_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.getscoreboard(contest_id integer) TO erfang;


--
-- TOC entry 5075 (class 0 OID 0)
-- Dependencies: 215
-- Name: TABLE "User"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."User" TO erfang;


--
-- TOC entry 5076 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE admin_contest; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.admin_contest TO erfang;


--
-- TOC entry 5077 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE code; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.code TO erfang;


--
-- TOC entry 5079 (class 0 OID 0)
-- Dependencies: 222
-- Name: SEQUENCE code_code_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.code_code_id_seq TO erfang;


--
-- TOC entry 5080 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE contest; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.contest TO erfang;


--
-- TOC entry 5082 (class 0 OID 0)
-- Dependencies: 216
-- Name: SEQUENCE contest_contest_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.contest_contest_id_seq TO erfang;


--
-- TOC entry 5083 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE contest_problem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.contest_problem TO erfang;


--
-- TOC entry 5084 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE contest_user; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.contest_user TO erfang;


--
-- TOC entry 5085 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE problem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.problem TO erfang;


--
-- TOC entry 5087 (class 0 OID 0)
-- Dependencies: 220
-- Name: SEQUENCE problem_problem_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.problem_problem_id_seq TO erfang;


--
-- TOC entry 5088 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE tag; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tag TO erfang;


--
-- TOC entry 5089 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE tag_problem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.tag_problem TO erfang;


--
-- TOC entry 5090 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE testcase; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.testcase TO erfang;


--
-- TOC entry 5092 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE testcase_testcase_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.testcase_testcase_id_seq TO erfang;


--
-- TOC entry 5093 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE toturial; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.toturial TO erfang;


--
-- TOC entry 2133 (class 826 OID 240296)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO erfang;


--
-- TOC entry 2135 (class 826 OID 240298)
-- Name: DEFAULT PRIVILEGES FOR TYPES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TYPES TO erfang;


--
-- TOC entry 2134 (class 826 OID 240297)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO erfang;


--
-- TOC entry 2136 (class 826 OID 240295)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO erfang;


-- Completed on 2025-05-25 22:07:40

--
-- PostgreSQL database dump complete
--

