--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.1
-- Dumped by pg_dump version 9.5.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: id; Type: SEQUENCE; Schema: public; Owner: guest
--

CREATE SEQUENCE id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE id OWNER TO guest;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: routes; Type: TABLE; Schema: public; Owner: guest
--

CREATE TABLE routes (
    id integer DEFAULT nextval('id'::regclass) NOT NULL,
    request character varying NOT NULL,
    controller character varying NOT NULL,
    action character varying NOT NULL,
    name character varying,
    descr text,
    auth bit(1),
    disable bit(1)
);


ALTER TABLE routes OWNER TO guest;

--
-- Name: users; Type: TABLE; Schema: public; Owner: guest
--

CREATE TABLE users (
    id integer DEFAULT nextval('id'::regclass) NOT NULL,
    login character varying NOT NULL,
    pass character varying NOT NULL
);


ALTER TABLE users OWNER TO guest;

--
-- Name: id; Type: SEQUENCE SET; Schema: public; Owner: guest
--

SELECT pg_catalog.setval('id', 5, true);


--
-- Data for Name: routes; Type: TABLE DATA; Schema: public; Owner: guest
--

COPY routes (id, request, controller, action, name, descr, auth, disable) FROM stdin;
2	/	Main	index	home	\N	0	\N
3	/sign/:login/:pass	Main	sign	sign in&up	\N	0	\N
5	/signout	Main	signout	go away	\N	1	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: guest
--

COPY users (id, login, pass) FROM stdin;
4	вася	пупкин
\.


--
-- Name: routes_pkey; Type: CONSTRAINT; Schema: public; Owner: guest
--

ALTER TABLE ONLY routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: guest
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: public; Type: ACL; Schema: -; Owner: guest
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM guest;
GRANT ALL ON SCHEMA public TO guest;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

