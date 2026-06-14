/*
Script FestCine corregido e integrado.
Incluye las 15 correcciones detectadas:
1) EventosParalelos ahora tiene IdEdicion.
2) Se agrega SedeEdicion para registrar sedes por edicion.
3) SP_ComprarEntrada valida tarifas gratuitas Acreditado/VIP.
4) SP_VenderAbono valida tarifas gratuitas Acreditado/VIP.
5) Se evita doble entrada del mismo asistente a la misma proyeccion.
6) Se corrige la restriccion real de duplicidad con indice filtrado.
7) Trigger controla que asistencia real no supere capacidad.
8) Trigger de agenda controla INSERT y UPDATE de Proyecciones.
9) Trigger de agenda controla INSERT y UPDATE de EventosParalelos.
10) Triggers de agenda se crean antes de poblar datos.
11) Procedimientos usan SEQUENCE en vez de MAX(ID)+1.
12) SP_VenderAbono tiene reglas diferenciadas por tipo de abono.
13) Trigger valida monto de Factura contra detalle de entradas/abonos.
14) Informe financiero separa entradas de proyeccion y evento paralelo.
15) SP_VenderAbono evita SET DATEFIRST y calcula fin de semana de forma estable.
16) ParticipacionPelicula y SedeEdicion usan PK compuesta por sus llaves foraneas, al ser asociativas puras.
17) SP_ComprarEntrada ahora crea automaticamente el registro en AsistenciaProyeccion usando SeqAsistencia.
*/

CREATE DATABASE FestCine;
GO

USE FestCine;
GO

CREATE TABLE Persona 
(
	IdPersona CHAR(5) PRIMARY KEY,
	Nombre VARCHAR(50) NOT NULL,
	Apellido VARCHAR(30) NOT NULL,
	Correo VARCHAR(100) NOT NULL UNIQUE,
	Telefono VARCHAR(20)
);

CREATE TABLE Edicion 
(
	IdEdicion CHAR(5) PRIMARY KEY,
	NombreEdicion VARCHAR(50) NOT NULL,
	FechaInicio DATE NOT NULL,
	FechaFin DATE NOT NULL,
	EstadoEdicion VARCHAR(20) NOT NULL,

	CONSTRAINT CK_Edicion_Fechas CHECK (FechaFin >= FechaInicio),
	CONSTRAINT CK_Edicion_Estado CHECK (EstadoEdicion IN ('Planificada', 'Actual', 'Finalizada', 'Cancelada'))
);

CREATE TABLE Pelicula 
(
	IdPelicula CHAR(5) PRIMARY KEY,
	Titulo VARCHAR(80) NOT NULL,
	AnioProduccion INT NOT NULL,
	Duracion INT NOT NULL,
	PaisOrigen VARCHAR(50) NOT NULL,
	Sinopsis VARCHAR(600),
	ClasEdad VARCHAR(20),
	FormatoProyeccion VARCHAR(50) NOT NULL,

	CONSTRAINT CK_Pelicula_Anio CHECK (AnioProduccion > 0),
	CONSTRAINT CK_Pelicula_Duracion CHECK (Duracion > 0),
	CONSTRAINT CK_Pelicula_Formato CHECK (FormatoProyeccion IN ('Digital', '35mm', 'IMAX'))
);

CREATE TABLE PeliculaEdicion
(
	IdPeliculaEdicion CHAR(5) PRIMARY KEY,
	IdPelicula CHAR(5) NOT NULL,
	IdEdicion CHAR(5) NOT NULL,
	EstadoFestival VARCHAR(20) NOT NULL,

	CONSTRAINT FK_PelEdi_Pelicula FOREIGN KEY (IdPelicula) REFERENCES Pelicula(IdPelicula),
	CONSTRAINT FK_PelEdi_Edicion FOREIGN KEY (IdEdicion) REFERENCES Edicion(IdEdicion),

	CONSTRAINT CK_PelEdi_Estado 
		CHECK (EstadoFestival IN ('Postulada', 'Seleccionada', 'Rechazada', 'Premiada')),

	CONSTRAINT UQ_Pelicula_Edicion UNIQUE (IdPelicula, IdEdicion)
);

CREATE TABLE Genero 
(
	IdGenero CHAR(5) PRIMARY KEY,
	NombreGenero VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE PeliculaGenero
(
	IdPelicula CHAR(5) NOT NULL,
	IdGenero CHAR(5) NOT NULL,

	CONSTRAINT PK_PeliculaGenero PRIMARY KEY (IdPelicula, IdGenero),
	CONSTRAINT FK_PelGen_Pelicula FOREIGN KEY (IdPelicula) REFERENCES Pelicula(IdPelicula),
	CONSTRAINT FK_PelGen_Genero FOREIGN KEY (IdGenero) REFERENCES Genero(IdGenero)
);

CREATE TABLE PersonalCinematografico 
(
	IdPersonal CHAR(5) PRIMARY KEY,
	Biografia VARCHAR(500),
	Pais VARCHAR(50),
	IdPersona CHAR(5) NOT NULL,

	CONSTRAINT FK_PC_Persona FOREIGN KEY (IdPersona) REFERENCES Persona(IdPersona),
	CONSTRAINT UQ_PC_Persona UNIQUE (IdPersona)
);

CREATE TABLE RolCinematografico
(
	IdRol CHAR(5) PRIMARY KEY,
	NombreRol VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE ParticipacionPelicula
(
	IdPersonal CHAR(5) NOT NULL,
	IdPelicula CHAR(5) NOT NULL,
	IdRol CHAR(5) NOT NULL,

	CONSTRAINT PK_ParticipacionPelicula PRIMARY KEY (IdPersonal, IdPelicula, IdRol),
	CONSTRAINT FK_Par_Personal FOREIGN KEY (IdPersonal) REFERENCES PersonalCinematografico(IdPersonal),
	CONSTRAINT FK_Par_Pelicula FOREIGN KEY (IdPelicula) REFERENCES Pelicula(IdPelicula),
	CONSTRAINT FK_Par_Rol FOREIGN KEY (IdRol) REFERENCES RolCinematografico(IdRol)
);

CREATE TABLE Patrocinador 
(
	IdPatrocinador CHAR(5) PRIMARY KEY,
	NombrePatrocinador VARCHAR(80) NOT NULL,
	Telefono VARCHAR(20),
	Correo VARCHAR(100)
);

CREATE TABLE Patrocinio
(
	IdPatrocinio CHAR(5) PRIMARY KEY,
	IdPatrocinador CHAR(5) NOT NULL,
	IdEdicion CHAR(5) NOT NULL,
	TipoAportacion VARCHAR(50) NOT NULL,
	Monto DECIMAL(10,2),
	DescripcionAportacion VARCHAR(200),

	CONSTRAINT FK_Patrocinio_Patrocinador FOREIGN KEY (IdPatrocinador) REFERENCES Patrocinador(IdPatrocinador),
	CONSTRAINT FK_Patrocinio_Edicion FOREIGN KEY (IdEdicion) REFERENCES Edicion(IdEdicion),

	CONSTRAINT CK_Patrocinio_Tipo CHECK (TipoAportacion IN ('Economica', 'Especie')),
	CONSTRAINT CK_Patrocinio_Monto CHECK (Monto IS NULL OR Monto >= 0)
);

CREATE TABLE Sede
(
	IdSede CHAR(5) PRIMARY KEY,
	NombreSede VARCHAR(80) NOT NULL,
	Direccion VARCHAR(100) NOT NULL,
	Ciudad VARCHAR(50)
);

CREATE TABLE SedeEdicion
(
	IdSede CHAR(5) NOT NULL,
	IdEdicion CHAR(5) NOT NULL,

	CONSTRAINT PK_SedeEdicion PRIMARY KEY (IdSede, IdEdicion),
	CONSTRAINT FK_SedeEdicion_Sede FOREIGN KEY (IdSede) REFERENCES Sede(IdSede),
	CONSTRAINT FK_SedeEdicion_Edicion FOREIGN KEY (IdEdicion) REFERENCES Edicion(IdEdicion)
);

CREATE TABLE Salas 
(
	IdSala CHAR(5) PRIMARY KEY,
	NroSala INT NOT NULL,
	NombreSala VARCHAR(50) NOT NULL,
	Capacidad INT NOT NULL,
	IdSede CHAR(5) NOT NULL,

	CONSTRAINT FK_Sala_Sede FOREIGN KEY (IdSede) REFERENCES Sede(IdSede),
	CONSTRAINT CK_Sala_Capacidad CHECK (Capacidad > 0),
	CONSTRAINT UQ_Sala_Sede_Numero UNIQUE (IdSede, NroSala)
);

CREATE TABLE Proyecciones 
(
	IdProyeccion CHAR(5) PRIMARY KEY,
	FechaHoraInicio DATETIME NOT NULL,
	TieneQA BIT NOT NULL DEFAULT 0,
	IdSala CHAR(5) NOT NULL,
	IdPeliculaEdicion CHAR(5) NOT NULL,

	CONSTRAINT FK_Pro_Sala FOREIGN KEY (IdSala) REFERENCES Salas(IdSala),
	CONSTRAINT FK_Pro_PeliculaEdicion FOREIGN KEY (IdPeliculaEdicion) REFERENCES PeliculaEdicion(IdPeliculaEdicion)
);

CREATE TABLE Expositor 
(
	IdExpositor CHAR(5) PRIMARY KEY,
	TemaExposicion VARCHAR(80) NOT NULL,
	Descripcion VARCHAR(200), 
	Biografia VARCHAR(600), 
	Pais VARCHAR(50) NOT NULL,
	IdPersona CHAR(5) NOT NULL,

	CONSTRAINT FK_Expositor_Persona FOREIGN KEY (IdPersona) REFERENCES Persona(IdPersona),
	CONSTRAINT UQ_Expositor_Persona UNIQUE (IdPersona)
);

CREATE TABLE EventosParalelos 
(
	IdEvento CHAR(5) PRIMARY KEY,
	NombreEvento VARCHAR(100) NOT NULL,
	TipoEvento VARCHAR(50) NOT NULL,
	Descripcion VARCHAR(200), 
	Aforo INT NOT NULL,
	Costo DECIMAL(10,2) NOT NULL,
	FechaHoraInicio DATETIME NOT NULL,
	DuracionMinutos INT NOT NULL,
	IdEdicion CHAR(5) NOT NULL,
	IdSala CHAR(5) NOT NULL,

	CONSTRAINT FK_Evento_Edicion FOREIGN KEY (IdEdicion) REFERENCES Edicion(IdEdicion),
	CONSTRAINT FK_Evento_Sala FOREIGN KEY (IdSala) REFERENCES Salas(IdSala),

	CONSTRAINT CK_Evento_Aforo CHECK (Aforo > 0),
	CONSTRAINT CK_Evento_Costo CHECK (Costo >= 0),
	CONSTRAINT CK_Evento_Duracion CHECK (DuracionMinutos > 0),
	CONSTRAINT CK_Evento_Tipo CHECK (TipoEvento IN ('Masterclass', 'Taller', 'Coctel'))
);

CREATE TABLE EventoExpositor
(
	IdEvento CHAR(5) NOT NULL,
	IdExpositor CHAR(5) NOT NULL,

	CONSTRAINT PK_EventoExpositor PRIMARY KEY (IdEvento, IdExpositor),

	CONSTRAINT FK_EvExp_Evento FOREIGN KEY (IdEvento) REFERENCES EventosParalelos(IdEvento),
	CONSTRAINT FK_EvExp_Expositor FOREIGN KEY (IdExpositor) REFERENCES Expositor(IdExpositor)
);

CREATE TABLE Asistentes 
(
	IdAsistente CHAR(5) PRIMARY KEY,
	EstadoAsistencia VARCHAR(20) NOT NULL,
	FechaRegistro DATE NOT NULL,
	IdEdicion CHAR(5) NOT NULL,
	IdPersona CHAR(5) NOT NULL,

	CONSTRAINT FK_Asis_Persona FOREIGN KEY (IdPersona) REFERENCES Persona(IdPersona),
	CONSTRAINT FK_Asis_Edicion FOREIGN KEY (IdEdicion) REFERENCES Edicion(IdEdicion),

	CONSTRAINT CK_Asis_Estado CHECK (EstadoAsistencia IN ('Registrado', 'Activo', 'Inactivo')),

	CONSTRAINT UQ_Asistente_Persona_Edicion UNIQUE (IdPersona, IdEdicion)
);

CREATE TABLE TipoAcreditacion
(
	IdTipoAcreditacion CHAR(5) PRIMARY KEY,
	NombreTipo VARCHAR(30) NOT NULL UNIQUE,

	CONSTRAINT CK_TipoAcreditacion_Nombre CHECK (NombreTipo IN ('Prensa', 'Industria', 'VIP', 'Jurado'))
);

CREATE TABLE Acreditacion 
(
	IdAcreditacion CHAR(5) PRIMARY KEY,
	IdAsistente CHAR(5) NOT NULL,
	IdTipoAcreditacion CHAR(5) NOT NULL,
	FechaEmision DATE NOT NULL,
	EstadoAcreditacion VARCHAR(20) NOT NULL,

	CONSTRAINT FK_Acre_Asistente FOREIGN KEY (IdAsistente) REFERENCES Asistentes(IdAsistente),
	CONSTRAINT FK_Acre_Tipo FOREIGN KEY (IdTipoAcreditacion) REFERENCES TipoAcreditacion(IdTipoAcreditacion),

	CONSTRAINT CK_Acre_Estado CHECK (EstadoAcreditacion IN ('Activa', 'Suspendida', 'Vencida')),

	CONSTRAINT UQ_Acreditacion_Asistente UNIQUE (IdAsistente)
);

CREATE TABLE Alojamiento
(
	IdAlojamiento CHAR(5) PRIMARY KEY,
	NombreAlojamiento VARCHAR(80) NOT NULL,
	Habitacion VARCHAR(20) NOT NULL,
	FechaEntrada DATE NOT NULL, 
	FechaSalida DATE NOT NULL,
	IdAsistente CHAR(5) NOT NULL,

	CONSTRAINT FK_Alojamiento_Asistente FOREIGN KEY (IdAsistente) REFERENCES Asistentes(IdAsistente),
	CONSTRAINT CK_Alojamiento_Fechas CHECK (FechaSalida >= FechaEntrada)
);

CREATE TABLE Traslados
(
	IdTraslado CHAR(5) PRIMARY KEY,
	UbiPartida VARCHAR(100) NOT NULL,
	UbiDestino VARCHAR(100) NOT NULL,
	TipoTransporte VARCHAR(50) NOT NULL, 
	FechaHoraTraslado DATETIME NOT NULL,
	Itinerario VARCHAR(200),
	IdAsistente CHAR(5) NOT NULL,

	CONSTRAINT FK_Traslado_Asistente FOREIGN KEY (IdAsistente) REFERENCES Asistentes(IdAsistente)
);

CREATE TABLE Compra 
(
	IdCompra CHAR(5) PRIMARY KEY,
	FechaHoraCompra DATETIME NOT NULL,
	MetodoPago VARCHAR(50) NOT NULL,
	IdEdicion CHAR(5) NOT NULL,

	CONSTRAINT FK_Compra_Edicion FOREIGN KEY (IdEdicion) REFERENCES Edicion(IdEdicion),

	CONSTRAINT CK_Compra_MetodoPago CHECK (MetodoPago IN ('Efectivo', 'Tarjeta', 'QR', 'Transferencia'))
);

CREATE TABLE Tarifas
(
	IdTarifa CHAR(5) PRIMARY KEY,
	TipoTarifa VARCHAR(30) NOT NULL,
	Precio DECIMAL(10,2) NOT NULL,
	Descripcion VARCHAR(200),

	CONSTRAINT CK_Tarifa_Precio CHECK (Precio >= 0),

	CONSTRAINT CK_Tarifa_Tipo CHECK (TipoTarifa IN ('General', 'Estudiante', 'Jubilado', 'Acreditado', 'VIP')),

	CONSTRAINT UQ_Tarifa_Tipo UNIQUE (TipoTarifa)
);

CREATE TABLE Factura 
(
	IdFactura CHAR(5) PRIMARY KEY,
	NIT VARCHAR(20),
	NombreCompra VARCHAR(80),
	Monto DECIMAL(10,2) NOT NULL,
	IdCompra CHAR(5) NOT NULL,

	CONSTRAINT FK_Factura_Compra FOREIGN KEY (IdCompra) REFERENCES Compra(IdCompra),

	CONSTRAINT CK_Factura_Monto CHECK (Monto >= 0),

	CONSTRAINT UQ_Factura_Compra UNIQUE (IdCompra)
);

CREATE TABLE TipoAbono
(
	IdTipoAbono CHAR(5) PRIMARY KEY,
	NombreTipoAbono VARCHAR(50) NOT NULL UNIQUE,
	Descripcion VARCHAR(200),
	PrecioBase DECIMAL(10,2) NOT NULL,

	CONSTRAINT CK_TipoAbono_Precio CHECK (PrecioBase >= 0)
);

CREATE TABLE Abono 
(
	IdAbono CHAR(5) PRIMARY KEY,
	CodigoAbono VARCHAR(30) NOT NULL UNIQUE,
	PrecioAplicado DECIMAL(10,2) NOT NULL,
	EstadoAbono VARCHAR(20) NOT NULL DEFAULT 'Activo',
	IdCompra CHAR(5) NOT NULL,
	IdAsistente CHAR(5) NOT NULL,
	IdTipoAbono CHAR(5) NOT NULL,
	IdTarifa CHAR(5) NOT NULL,

	CONSTRAINT FK_Abono_Compra FOREIGN KEY (IdCompra) REFERENCES Compra(IdCompra),
	CONSTRAINT FK_Abono_Asistente FOREIGN KEY (IdAsistente) REFERENCES Asistentes(IdAsistente),
	CONSTRAINT FK_Abono_TipoAbono FOREIGN KEY (IdTipoAbono) REFERENCES TipoAbono(IdTipoAbono),
	CONSTRAINT FK_Abono_Tarifa FOREIGN KEY (IdTarifa) REFERENCES Tarifas(IdTarifa),

	CONSTRAINT CK_Abono_Precio CHECK (PrecioAplicado >= 0),

	CONSTRAINT CK_Abono_Estado CHECK (EstadoAbono IN ('Activo', 'Usado', 'Anulado'))
);

CREATE TABLE AbonoProyeccion
(
	IdAbono CHAR(5) NOT NULL,
	IdProyeccion CHAR(5) NOT NULL,

	CONSTRAINT PK_AbonoProyeccion PRIMARY KEY (IdAbono, IdProyeccion),

	CONSTRAINT FK_AboPro_Abono FOREIGN KEY (IdAbono) REFERENCES Abono(IdAbono),
	CONSTRAINT FK_AboPro_Proyeccion FOREIGN KEY (IdProyeccion) REFERENCES Proyecciones(IdProyeccion)
);

CREATE TABLE EntradasIndividuales 
(
	IdEntrada CHAR(5) PRIMARY KEY,
	CodigoEntrada VARCHAR(30) NOT NULL UNIQUE,
	NroAsiento INT NULL,
	PrecioAplicado DECIMAL(10,2) NOT NULL,
	IdCompra CHAR(5) NOT NULL,
	IdProyeccion CHAR(5) NULL,
	IdEvento CHAR(5) NULL,
	IdAsistente CHAR(5) NOT NULL,
	IdTarifa CHAR(5) NOT NULL,

	CONSTRAINT FK_Ent_Compra FOREIGN KEY (IdCompra) REFERENCES Compra(IdCompra),
	CONSTRAINT FK_Ent_Proyeccion FOREIGN KEY (IdProyeccion) REFERENCES Proyecciones(IdProyeccion),
	CONSTRAINT FK_Ent_Evento FOREIGN KEY (IdEvento) REFERENCES EventosParalelos(IdEvento),
	CONSTRAINT FK_Ent_Asistente FOREIGN KEY (IdAsistente) REFERENCES Asistentes(IdAsistente),
	CONSTRAINT FK_Ent_Tarifa FOREIGN KEY (IdTarifa) REFERENCES Tarifas(IdTarifa),

	CONSTRAINT CK_Entrada_Asiento CHECK (NroAsiento IS NULL OR NroAsiento > 0),
	CONSTRAINT CK_Entrada_Precio CHECK (PrecioAplicado >= 0),

	CONSTRAINT CK_Entrada_TipoDestino CHECK
	(
		(IdProyeccion IS NOT NULL AND IdEvento IS NULL)
		OR
		(IdProyeccion IS NULL AND IdEvento IS NOT NULL)
	),

	CONSTRAINT UQ_Entrada_Proyeccion UNIQUE (IdEntrada, IdProyeccion),
	CONSTRAINT UQ_Entrada_Proy_Asis UNIQUE (IdEntrada, IdProyeccion, IdAsistente)
);

CREATE UNIQUE INDEX UQ_Entrada_Asiento_Proyeccion
ON EntradasIndividuales(IdProyeccion, NroAsiento)
WHERE IdProyeccion IS NOT NULL AND NroAsiento IS NOT NULL;


CREATE UNIQUE INDEX UQ_Entrada_Proyeccion_Asistente
ON EntradasIndividuales(IdProyeccion, IdAsistente)
WHERE IdProyeccion IS NOT NULL;

CREATE TABLE AsistenciaProyeccion
(
	IdAsistencia CHAR(5) PRIMARY KEY,
	FechaHoraControl DATETIME NOT NULL,
	Asistio BIT NOT NULL DEFAULT 1,
	IdProyeccion CHAR(5) NOT NULL,
	IdAsistente CHAR(5) NOT NULL,
	IdEntrada CHAR(5) NULL,
	IdAbono CHAR(5) NULL,

	CONSTRAINT FK_AsiPro_Proyeccion FOREIGN KEY (IdProyeccion) REFERENCES Proyecciones(IdProyeccion),
	CONSTRAINT FK_AsiPro_Asistente FOREIGN KEY (IdAsistente) REFERENCES Asistentes(IdAsistente),

	CONSTRAINT FK_AsiPro_Entrada 
		FOREIGN KEY (IdEntrada, IdProyeccion, IdAsistente) 
		REFERENCES EntradasIndividuales(IdEntrada, IdProyeccion, IdAsistente),

	CONSTRAINT FK_AsiPro_Abono 
		FOREIGN KEY (IdAbono, IdProyeccion) 
		REFERENCES AbonoProyeccion(IdAbono, IdProyeccion),

	CONSTRAINT CK_Asistencia_TipoAcceso CHECK
	(
		(IdEntrada IS NOT NULL AND IdAbono IS NULL)
		OR
		(IdEntrada IS NULL AND IdAbono IS NOT NULL)
	),

	CONSTRAINT UQ_Asistencia_Proy_Asis UNIQUE (IdProyeccion, IdAsistente)
);

CREATE TABLE Jurado 
(
	IdJurado CHAR(5) PRIMARY KEY,
	EstadoAsistencia VARCHAR(20) NOT NULL,
	Especialidad VARCHAR(50),
	TipoJurado VARCHAR(50),
	IdPersona CHAR(5) NOT NULL,

	CONSTRAINT FK_Jurado_Persona FOREIGN KEY (IdPersona) REFERENCES Persona(IdPersona),
	CONSTRAINT UQ_Jurado_Persona UNIQUE (IdPersona),

	CONSTRAINT CK_Jurado_Estado CHECK (EstadoAsistencia IN ('Presente', 'Ausente', 'Pendiente'))
);

CREATE TABLE CategoriasCompeticion 
(
	IdCategoria CHAR(5) PRIMARY KEY,
	NombreCategoria VARCHAR(80) NOT NULL,
	Descripcion VARCHAR(200), 
	IdEdicion CHAR(5) NOT NULL,

	CONSTRAINT FK_Categoria_Edicion FOREIGN KEY (IdEdicion) REFERENCES Edicion(IdEdicion),

	CONSTRAINT UQ_Categoria_Edicion_Nombre UNIQUE (IdEdicion, NombreCategoria)
);

CREATE TABLE CategoriaJurado
(
	IdCategoria CHAR(5) NOT NULL,
	IdJurado CHAR(5) NOT NULL,

	CONSTRAINT PK_CategoriaJurado PRIMARY KEY (IdCategoria, IdJurado),

	CONSTRAINT FK_CatJur_Categoria FOREIGN KEY (IdCategoria) REFERENCES CategoriasCompeticion(IdCategoria),
	CONSTRAINT FK_CatJur_Jurado FOREIGN KEY (IdJurado) REFERENCES Jurado(IdJurado)
);

CREATE TABLE PeliculaCompite 
(
	IdCompetencia CHAR(5) PRIMARY KEY,
	EstadoParticipacion VARCHAR(50),
	FechaParticipacion DATE,
	IdCategoria CHAR(5) NOT NULL,
	IdPeliculaEdicion CHAR(5) NOT NULL,

	CONSTRAINT FK_Comp_Categoria FOREIGN KEY (IdCategoria) REFERENCES CategoriasCompeticion(IdCategoria),
	CONSTRAINT FK_Comp_PeliculaEdicion FOREIGN KEY (IdPeliculaEdicion) REFERENCES PeliculaEdicion(IdPeliculaEdicion),

	CONSTRAINT UQ_Comp_Categoria_PeliculaEdicion UNIQUE (IdCategoria, IdPeliculaEdicion),
	CONSTRAINT UQ_Comp_Cat UNIQUE (IdCompetencia, IdCategoria)
);

CREATE TABLE Evaluacion 
(
	IdEvaluacion CHAR(5) PRIMARY KEY,
	Puntuacion DECIMAL(4,2) NOT NULL,
	Comentario VARCHAR(200),
	FechaEvaluacion DATE NOT NULL,
	IdJurado CHAR(5) NOT NULL,
	IdCategoria CHAR(5) NOT NULL,
	IdCompetencia CHAR(5) NOT NULL,

	CONSTRAINT CK_Evaluacion_Puntuacion CHECK (Puntuacion BETWEEN 1 AND 10),

	CONSTRAINT FK_Eva_Competencia_Categoria 
		FOREIGN KEY (IdCompetencia, IdCategoria) 
		REFERENCES PeliculaCompite(IdCompetencia, IdCategoria),

	CONSTRAINT FK_Eva_Categoria_Jurado 
		FOREIGN KEY (IdCategoria, IdJurado) 
		REFERENCES CategoriaJurado(IdCategoria, IdJurado),

	CONSTRAINT UQ_Eva_Jurado_Competencia UNIQUE (IdJurado, IdCompetencia)
);

CREATE TABLE Premio
(
	IdPremio CHAR(5) PRIMARY KEY,
	NombrePremio VARCHAR(80) NOT NULL,
	FechaPremiacion DATE NOT NULL,
	IdCompetencia CHAR(5) NOT NULL,
	IdCategoria CHAR(5) NOT NULL,

	CONSTRAINT FK_Pre_Competencia_Categoria 
		FOREIGN KEY (IdCompetencia, IdCategoria) 
		REFERENCES PeliculaCompite(IdCompetencia, IdCategoria),

	CONSTRAINT UQ_Premio_Categoria UNIQUE (IdCategoria)
);
GO

CREATE TRIGGER TR_ControlAgendaProyecciones/*Verifica que la sala esté habilitada para la edición actual*/
ON Proyecciones
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN Proyecciones PR
			ON I.IdProyeccion = PR.IdProyeccion
		INNER JOIN Salas S
			ON PR.IdSala = S.IdSala
		INNER JOIN PeliculaEdicion PE
			ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
		WHERE NOT EXISTS
		(
			SELECT 1
			FROM SedeEdicion SX
			WHERE SX.IdSede = S.IdSede
			  AND SX.IdEdicion = PE.IdEdicion
		)
	)
	BEGIN
		ROLLBACK TRANSACTION;/*Deshace el proceso anterior al no servir si el error se cumple*/
		RAISERROR('La sala de la proyeccion no esta habilitada para la edicion indicada.', 16, 1);
		RETURN;
	END;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN PeliculaEdicion PE_Nueva
			ON I.IdPeliculaEdicion = PE_Nueva.IdPeliculaEdicion
		INNER JOIN Pelicula P_Nueva
			ON PE_Nueva.IdPelicula = P_Nueva.IdPelicula
		INNER JOIN Proyecciones PR_Existente
			ON I.IdSala = PR_Existente.IdSala
			AND I.IdProyeccion <> PR_Existente.IdProyeccion
		INNER JOIN PeliculaEdicion PE_Existente
			ON PR_Existente.IdPeliculaEdicion = PE_Existente.IdPeliculaEdicion
		INNER JOIN Pelicula P_Existente
			ON PE_Existente.IdPelicula = P_Existente.IdPelicula
		WHERE 
			I.FechaHoraInicio < DATEADD(MINUTE, P_Existente.Duracion + 30, PR_Existente.FechaHoraInicio)
			AND DATEADD(MINUTE, P_Nueva.Duracion + 30, I.FechaHoraInicio) > PR_Existente.FechaHoraInicio
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('No se puede programar la proyeccion: existe cruce con otra proyeccion en la misma sala.', 16, 1);
		RETURN;
	END;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN PeliculaEdicion PE_Nueva
			ON I.IdPeliculaEdicion = PE_Nueva.IdPeliculaEdicion
		INNER JOIN Pelicula P_Nueva
			ON PE_Nueva.IdPelicula = P_Nueva.IdPelicula
		INNER JOIN EventosParalelos EV
			ON I.IdSala = EV.IdSala
		WHERE 
			I.FechaHoraInicio < DATEADD(MINUTE, EV.DuracionMinutos, EV.FechaHoraInicio)
			AND DATEADD(MINUTE, P_Nueva.Duracion + 30, I.FechaHoraInicio) > EV.FechaHoraInicio
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('No se puede programar la proyeccion: existe cruce con un evento paralelo en la misma sala.', 16, 1);
		RETURN;
	END;
END;
GO

CREATE TRIGGER TR_ControlAgendaEventos
ON EventosParalelos
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN Salas S
			ON I.IdSala = S.IdSala
		WHERE NOT EXISTS
		(
			SELECT 1
			FROM SedeEdicion SX
			WHERE SX.IdSede = S.IdSede
			  AND SX.IdEdicion = I.IdEdicion
		)
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('La sala del evento no esta habilitada para la edicion indicada.', 16, 1);
		RETURN;
	END;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN Proyecciones PR
			ON I.IdSala = PR.IdSala
		INNER JOIN PeliculaEdicion PE
			ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
		INNER JOIN Pelicula P
			ON PE.IdPelicula = P.IdPelicula
		WHERE
			I.FechaHoraInicio < DATEADD(MINUTE, P.Duracion + 30, PR.FechaHoraInicio)
			AND DATEADD(MINUTE, I.DuracionMinutos, I.FechaHoraInicio) > PR.FechaHoraInicio
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('No se puede programar el evento: existe cruce con una proyeccion en la misma sala.', 16, 1);
		RETURN;
	END;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN EventosParalelos EV
			ON I.IdSala = EV.IdSala
			AND I.IdEvento <> EV.IdEvento
		WHERE
			I.FechaHoraInicio < DATEADD(MINUTE, EV.DuracionMinutos, EV.FechaHoraInicio)
			AND DATEADD(MINUTE, I.DuracionMinutos, I.FechaHoraInicio) > EV.FechaHoraInicio
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('No se puede programar el evento: existe cruce con otro evento en la misma sala.', 16, 1);
		RETURN;
	END;
END;
GO

CREATE TRIGGER TR_ControlAsistenciaProyeccion
ON AsistenciaProyeccion
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN Proyecciones PR
			ON I.IdProyeccion = PR.IdProyeccion
		INNER JOIN PeliculaEdicion PE
			ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
		INNER JOIN Asistentes A
			ON I.IdAsistente = A.IdAsistente
		WHERE A.IdEdicion <> PE.IdEdicion
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('El asistente no pertenece a la edicion de la proyeccion.', 16, 1);
		RETURN;
	END;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		INNER JOIN Abono A
			ON I.IdAbono = A.IdAbono
		WHERE I.IdAbono IS NOT NULL
		  AND A.IdAsistente <> I.IdAsistente
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('El abono utilizado no pertenece al asistente indicado.', 16, 1);
		RETURN;
	END;

	IF EXISTS
	(
		SELECT 1
		FROM AsistenciaProyeccion AP
		INNER JOIN Proyecciones PR
			ON AP.IdProyeccion = PR.IdProyeccion
		INNER JOIN Salas S
			ON PR.IdSala = S.IdSala
		WHERE AP.Asistio = 1
		GROUP BY AP.IdProyeccion, S.Capacidad
		HAVING COUNT(*) > S.Capacidad
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('La asistencia registrada supera la capacidad de la sala.', 16, 1);
		RETURN;
	END;
END;
GO


USE FestCine;

INSERT INTO Persona VALUES ('PE001', 'Laura', 'Mendez', 'laura.mendez@festcine.com', '72110001');
INSERT INTO Persona VALUES ('PE002', 'Diego', 'Vargas', 'diego.vargas@festcine.com', '72110002');
INSERT INTO Persona VALUES ('PE003', 'Ana', 'Rojas', 'ana.rojas@festcine.com', '72110003');
INSERT INTO Persona VALUES ('PE004', 'Mateo', 'Suarez', 'mateo.suarez@festcine.com', '72110004');
INSERT INTO Persona VALUES ('PE005', 'Sofia', 'Rivera', 'sofia.rivera@festcine.com', '72110005');
INSERT INTO Persona VALUES ('PE006', 'Carlos', 'Quiroga', 'carlos.quiroga@festcine.com', '72110006');
INSERT INTO Persona VALUES ('PE007', 'Valeria', 'Cortez', 'valeria.cortez@festcine.com', '72110007');
INSERT INTO Persona VALUES ('PE008', 'Hector', 'Salinas', 'hector.salinas@festcine.com', '72110008');
INSERT INTO Persona VALUES ('PE009', 'Lucia', 'Fernandez', 'lucia.fernandez@festcine.com', '72110009');
INSERT INTO Persona VALUES ('PE010', 'Martin', 'Arias', 'martin.arias@festcine.com', '72110010');
INSERT INTO Persona VALUES ('PE011', 'Camila', 'Flores', 'camila.flores@festcine.com', '72110011');
INSERT INTO Persona VALUES ('PE012', 'Andres', 'Molina', 'andres.molina@festcine.com', '72110012');
INSERT INTO Persona VALUES ('PE013', 'Paula', 'Castro', 'paula.castro@festcine.com', '72110013');
INSERT INTO Persona VALUES ('PE014', 'Javier', 'Paredes', 'javier.paredes@festcine.com', '72110014');
INSERT INTO Persona VALUES ('PE015', 'Mariana', 'Lopez', 'mariana.lopez@festcine.com', '72110015');
INSERT INTO Persona VALUES ('PE016', 'Rodrigo', 'Vega', 'rodrigo.vega@festcine.com', '72110016');
INSERT INTO Persona VALUES ('PE017', 'Daniela', 'Soto', 'daniela.soto@festcine.com', '72110017');
INSERT INTO Persona VALUES ('PE018', 'Nicolas', 'Rivas', 'nicolas.rivas@festcine.com', '72110018');
INSERT INTO Persona VALUES ('PE019', 'Elena', 'Morales', 'elena.morales@festcine.com', '72110019');
INSERT INTO Persona VALUES ('PE020', 'Gabriel', 'Torres', 'gabriel.torres@festcine.com', '72110020');
INSERT INTO Persona VALUES ('PE021', 'Renata', 'Ibarra', 'renata.ibarra@festcine.com', '72110021');
INSERT INTO Persona VALUES ('PE022', 'Samuel', 'Luna', 'samuel.luna@festcine.com', '72110022');
INSERT INTO Persona VALUES ('PE023', 'Isabel', 'Mamani', 'isabel.mamani@festcine.com', '72110023');
INSERT INTO Persona VALUES ('PE024', 'Tomas', 'Gutierrez', 'tomas.gutierrez@festcine.com', '72110024');
INSERT INTO Persona VALUES ('PE025', 'Adriana', 'Ribera', 'adriana.ribera@festcine.com', '72110025');
INSERT INTO Persona VALUES ('PE026', 'Oscar', 'Benitez', 'oscar.benitez@festcine.com', '72110026');
INSERT INTO Persona VALUES ('PE027', 'Silvia', 'Campos', 'silvia.campos@festcine.com', '72110027');
INSERT INTO Persona VALUES ('PE028', 'Pablo', 'Herrera', 'pablo.herrera@festcine.com', '72110028');
INSERT INTO Persona VALUES ('PE029', 'Natalia', 'Aguilar', 'natalia.aguilar@festcine.com', '72110029');
INSERT INTO Persona VALUES ('PE030', 'Fernando', 'Medina', 'fernando.medina@festcine.com', '72110030');

INSERT INTO Edicion VALUES ('ED001', 'FestCine 2024', '2024-08-10', '2024-08-18', 'Finalizada');
INSERT INTO Edicion VALUES ('ED002', 'FestCine 2025', '2025-08-09', '2025-08-17', 'Finalizada');
INSERT INTO Edicion VALUES ('ED003', 'FestCine 2026', '2026-08-08', '2026-08-16', 'Actual');

INSERT INTO Pelicula VALUES ('PL001', 'La Ultima Luz', 2024, 95, 'Bolivia', 'Una joven documentalista registra los ultimos dias de una comunidad minera.', '13+', 'Digital');
INSERT INTO Pelicula VALUES ('PL002', 'Rio Seco', 2023, 88, 'Argentina', 'Un pueblo enfrenta la sequia y sus conflictos internos.', '13+', 'Digital');
INSERT INTO Pelicula VALUES ('PL003', 'El Eco del Viento', 2024, 102, 'Chile', 'Una directora vuelve a su ciudad natal para cerrar una herida familiar.', '16+', '35mm');
INSERT INTO Pelicula VALUES ('PL004', 'Sombras del Mercado', 2022, 76, 'Peru', 'Retrato urbano sobre comerciantes nocturnos.', '13+', 'Digital');
INSERT INTO Pelicula VALUES ('PL005', 'Niebla en Agosto', 2025, 110, 'Mexico', 'Drama psicologico sobre memoria y duelo.', '16+', 'IMAX');
INSERT INTO Pelicula VALUES ('PL006', 'La Casa Azul', 2023, 82, 'Colombia', 'Una familia reconstruye su historia a partir de cartas antiguas.', 'ATP', 'Digital');
INSERT INTO Pelicula VALUES ('PL007', 'Frontera Lunar', 2025, 98, 'España', 'Ciencia ficcion independiente sobre migracion espacial.', '13+', 'IMAX');
INSERT INTO Pelicula VALUES ('PL008', 'Voces de Tierra', 2024, 70, 'Bolivia', 'Documental sobre comunidades agricolas y cambio climatico.', 'ATP', 'Digital');

INSERT INTO PeliculaEdicion VALUES ('PX001', 'PL001', 'ED003', 'Premiada');
INSERT INTO PeliculaEdicion VALUES ('PX002', 'PL002', 'ED003', 'Seleccionada');
INSERT INTO PeliculaEdicion VALUES ('PX003', 'PL003', 'ED003', 'Premiada');
INSERT INTO PeliculaEdicion VALUES ('PX004', 'PL004', 'ED003', 'Seleccionada');
INSERT INTO PeliculaEdicion VALUES ('PX005', 'PL005', 'ED003', 'Premiada');
INSERT INTO PeliculaEdicion VALUES ('PX006', 'PL006', 'ED002', 'Seleccionada');
INSERT INTO PeliculaEdicion VALUES ('PX007', 'PL007', 'ED003', 'Postulada');
INSERT INTO PeliculaEdicion VALUES ('PX008', 'PL008', 'ED003', 'Seleccionada');

INSERT INTO Genero VALUES ('GE001', 'Drama');
INSERT INTO Genero VALUES ('GE002', 'Documental');
INSERT INTO Genero VALUES ('GE003', 'Ciencia Ficcion');
INSERT INTO Genero VALUES ('GE004', 'Suspenso');
INSERT INTO Genero VALUES ('GE005', 'Social');

INSERT INTO PeliculaGenero VALUES ('PL001', 'GE002');
INSERT INTO PeliculaGenero VALUES ('PL001', 'GE005');
INSERT INTO PeliculaGenero VALUES ('PL002', 'GE001');
INSERT INTO PeliculaGenero VALUES ('PL002', 'GE005');
INSERT INTO PeliculaGenero VALUES ('PL003', 'GE001');
INSERT INTO PeliculaGenero VALUES ('PL004', 'GE002');
INSERT INTO PeliculaGenero VALUES ('PL004', 'GE005');
INSERT INTO PeliculaGenero VALUES ('PL005', 'GE001');
INSERT INTO PeliculaGenero VALUES ('PL005', 'GE004');
INSERT INTO PeliculaGenero VALUES ('PL006', 'GE001');
INSERT INTO PeliculaGenero VALUES ('PL007', 'GE003');
INSERT INTO PeliculaGenero VALUES ('PL008', 'GE002');
INSERT INTO PeliculaGenero VALUES ('PL008', 'GE005');

INSERT INTO PersonalCinematografico VALUES ('PC001', 'Directora boliviana especializada en cine documental.', 'Bolivia', 'PE001');
INSERT INTO PersonalCinematografico VALUES ('PC002', 'Guionista argentino con trayectoria en cine social.', 'Argentina', 'PE002');
INSERT INTO PersonalCinematografico VALUES ('PC003', 'Productora chilena de cine independiente.', 'Chile', 'PE003');
INSERT INTO PersonalCinematografico VALUES ('PC004', 'Actor peruano de teatro y cine urbano.', 'Peru', 'PE004');
INSERT INTO PersonalCinematografico VALUES ('PC005', 'Directora mexicana enfocada en drama psicologico.', 'Mexico', 'PE005');
INSERT INTO PersonalCinematografico VALUES ('PC006', 'Director colombiano de cine familiar.', 'Colombia', 'PE006');
INSERT INTO PersonalCinematografico VALUES ('PC007', 'Productor español de ciencia ficcion independiente.', 'España', 'PE007');

INSERT INTO RolCinematografico VALUES ('RC001', 'Director');
INSERT INTO RolCinematografico VALUES ('RC002', 'Actor');
INSERT INTO RolCinematografico VALUES ('RC003', 'Guionista');
INSERT INTO RolCinematografico VALUES ('RC004', 'Productor');

INSERT INTO ParticipacionPelicula VALUES ('PC001', 'PL001', 'RC001');
INSERT INTO ParticipacionPelicula VALUES ('PC003', 'PL001', 'RC004');
INSERT INTO ParticipacionPelicula VALUES ('PC002', 'PL002', 'RC003');
INSERT INTO ParticipacionPelicula VALUES ('PC003', 'PL003', 'RC001');
INSERT INTO ParticipacionPelicula VALUES ('PC004', 'PL004', 'RC002');
INSERT INTO ParticipacionPelicula VALUES ('PC005', 'PL005', 'RC001');
INSERT INTO ParticipacionPelicula VALUES ('PC006', 'PL006', 'RC001');
INSERT INTO ParticipacionPelicula VALUES ('PC007', 'PL007', 'RC004');
INSERT INTO ParticipacionPelicula VALUES ('PC001', 'PL008', 'RC001');

INSERT INTO Patrocinador VALUES ('PA001', 'Cine Bolivia', '3331001', 'contacto@cinebolivia.com');
INSERT INTO Patrocinador VALUES ('PA002', 'Luz Media', '3331002', 'marketing@luzmedia.com');
INSERT INTO Patrocinador VALUES ('PA003', 'Hotel Centro', '3331003', 'reservas@hotelcentro.com');
INSERT INTO Patrocinador VALUES ('PA004', 'Audiovisual Sur', '3331004', 'alianzas@audiovisualsur.com');

INSERT INTO Patrocinio VALUES ('PT001', 'PA001', 'ED003', 'Economica', 25000.00, 'Aporte economico principal para la edicion 2026.');
INSERT INTO Patrocinio VALUES ('PT002', 'PA002', 'ED003', 'Economica', 15000.00, 'Aporte para difusion y cobertura audiovisual.');
INSERT INTO Patrocinio VALUES ('PT003', 'PA003', 'ED003', 'Especie', NULL, 'Hospedaje para invitados especiales.');
INSERT INTO Patrocinio VALUES ('PT004', 'PA004', 'ED002', 'Economica', 18000.00, 'Aporte economico para la edicion 2025.');

INSERT INTO Sede VALUES ('SE001', 'Cinemateca Central', 'Av. Cultura 100', 'Santa Cruz');
INSERT INTO Sede VALUES ('SE002', 'Centro Cultural Oriente', 'Calle Libertad 250', 'Santa Cruz');
INSERT INTO Sede VALUES ('SE003', 'Teatro Municipal Antiguo', 'Plaza Principal 20', 'Santa Cruz');

INSERT INTO SedeEdicion VALUES ('SE001', 'ED003');
INSERT INTO SedeEdicion VALUES ('SE002', 'ED003');
INSERT INTO SedeEdicion VALUES ('SE003', 'ED002');

INSERT INTO Salas VALUES ('SA001', 1, 'Sala Principal', 80, 'SE001');
INSERT INTO Salas VALUES ('SA002', 2, 'Sala Norte', 50, 'SE001');
INSERT INTO Salas VALUES ('SA003', 1, 'Auditorio Oriente', 120, 'SE002');
INSERT INTO Salas VALUES ('SA004', 2, 'Sala Experimental', 30, 'SE002');
INSERT INTO Salas VALUES ('SA005', 1, 'Sala Historica', 60, 'SE003');

INSERT INTO Proyecciones VALUES ('PR001', '2026-08-09T10:00:00', 1, 'SA001', 'PX001');
INSERT INTO Proyecciones VALUES ('PR002', '2026-08-09T15:00:00', 0, 'SA002', 'PX002');
INSERT INTO Proyecciones VALUES ('PR003', '2026-08-10T19:00:00', 1, 'SA003', 'PX003');
INSERT INTO Proyecciones VALUES ('PR004', '2026-08-11T11:00:00', 0, 'SA002', 'PX001');
INSERT INTO Proyecciones VALUES ('PR005', '2026-08-11T18:30:00', 1, 'SA004', 'PX004');
INSERT INTO Proyecciones VALUES ('PR006', '2026-08-12T20:00:00', 0, 'SA001', 'PX005');
INSERT INTO Proyecciones VALUES ('PR007', '2026-08-13T16:00:00', 0, 'SA004', 'PX002');
INSERT INTO Proyecciones VALUES ('PR008', '2026-08-14T17:00:00', 1, 'SA003', 'PX008');
INSERT INTO Proyecciones VALUES ('PR009', '2025-08-10T18:00:00', 0, 'SA005', 'PX006');
INSERT INTO Proyecciones VALUES ('PR010', '2026-08-15T20:00:00', 1, 'SA001', 'PX003');

INSERT INTO Expositor VALUES ('EX001', 'Produccion Independiente', 'Charla sobre gestion de rodajes de bajo presupuesto.', 'Productora invitada con experiencia internacional.', 'Chile', 'PE008');
INSERT INTO Expositor VALUES ('EX002', 'Distribucion Digital', 'Taller sobre plataformas y festivales digitales.', 'Consultor especializado en distribucion audiovisual.', 'Argentina', 'PE009');
INSERT INTO Expositor VALUES ('EX003', 'Cine y Comunidad', 'Masterclass sobre cine comunitario latinoamericano.', 'Director documentalista invitado.', 'Bolivia', 'PE010');

INSERT INTO EventosParalelos VALUES ('EV001', 'Miradas del Cine Social', 'Masterclass', 'Masterclass con invitados internacionales.', 100, 40.00, '2026-08-10T13:00:00', 120, 'ED003', 'SA003');
INSERT INTO EventosParalelos VALUES ('EV002', 'Distribuye tu Pelicula', 'Taller', 'Taller practico de distribucion digital.', 40, 60.00, '2026-08-11T15:00:00', 180, 'ED003', 'SA002');
INSERT INTO EventosParalelos VALUES ('EV003', 'Noche de Industria', 'Coctel', 'Coctel de networking para invitados.', 80, 0.00, '2026-08-12T20:30:00', 150, 'ED003', 'SA003');

INSERT INTO EventoExpositor VALUES ('EV001', 'EX001');
INSERT INTO EventoExpositor VALUES ('EV001', 'EX003');
INSERT INTO EventoExpositor VALUES ('EV002', 'EX002');
INSERT INTO EventoExpositor VALUES ('EV003', 'EX001');
INSERT INTO EventoExpositor VALUES ('EV003', 'EX003');

INSERT INTO Asistentes VALUES ('AS001', 'Registrado', '2026-07-25', 'ED003', 'PE011');
INSERT INTO Asistentes VALUES ('AS002', 'Registrado', '2026-07-25', 'ED003', 'PE012');
INSERT INTO Asistentes VALUES ('AS003', 'Registrado', '2026-07-26', 'ED003', 'PE013');
INSERT INTO Asistentes VALUES ('AS004', 'Registrado', '2026-07-26', 'ED003', 'PE014');
INSERT INTO Asistentes VALUES ('AS005', 'Registrado', '2026-07-26', 'ED003', 'PE015');
INSERT INTO Asistentes VALUES ('AS006', 'Registrado', '2026-07-27', 'ED003', 'PE016');
INSERT INTO Asistentes VALUES ('AS007', 'Registrado', '2026-07-27', 'ED003', 'PE017');
INSERT INTO Asistentes VALUES ('AS008', 'Registrado', '2026-07-27', 'ED003', 'PE018');
INSERT INTO Asistentes VALUES ('AS009', 'Registrado', '2026-07-28', 'ED003', 'PE019');
INSERT INTO Asistentes VALUES ('AS010', 'Registrado', '2026-07-28', 'ED003', 'PE020');
INSERT INTO Asistentes VALUES ('AS011', 'Registrado', '2026-07-29', 'ED003', 'PE021');
INSERT INTO Asistentes VALUES ('AS012', 'Registrado', '2026-07-29', 'ED003', 'PE022');
INSERT INTO Asistentes VALUES ('AS013', 'Registrado', '2026-07-30', 'ED003', 'PE023');
INSERT INTO Asistentes VALUES ('AS014', 'Registrado', '2026-07-30', 'ED003', 'PE024');
INSERT INTO Asistentes VALUES ('AS015', 'Registrado', '2026-07-31', 'ED003', 'PE025');
INSERT INTO Asistentes VALUES ('AS016', 'Registrado', '2026-07-31', 'ED003', 'PE026');
INSERT INTO Asistentes VALUES ('AS017', 'Registrado', '2026-08-01', 'ED003', 'PE027');
INSERT INTO Asistentes VALUES ('AS018', 'Registrado', '2026-08-01', 'ED003', 'PE028');
INSERT INTO Asistentes VALUES ('AS019', 'Registrado', '2026-08-02', 'ED003', 'PE029');
INSERT INTO Asistentes VALUES ('AS020', 'Registrado', '2026-08-02', 'ED003', 'PE030');

INSERT INTO TipoAcreditacion VALUES ('AT001', 'Prensa');
INSERT INTO TipoAcreditacion VALUES ('AT002', 'Industria');
INSERT INTO TipoAcreditacion VALUES ('AT003', 'VIP');
INSERT INTO TipoAcreditacion VALUES ('AT004', 'Jurado');

INSERT INTO Acreditacion VALUES ('AC001', 'AS004', 'AT001', '2026-07-21', 'Activa');
INSERT INTO Acreditacion VALUES ('AC002', 'AS005', 'AT002', '2026-07-22', 'Activa');
INSERT INTO Acreditacion VALUES ('AC003', 'AS006', 'AT003', '2026-07-23', 'Activa');
INSERT INTO Acreditacion VALUES ('AC004', 'AS009', 'AT001', '2026-07-24', 'Activa');
INSERT INTO Acreditacion VALUES ('AC005', 'AS010', 'AT003', '2026-07-24', 'Activa');
INSERT INTO Acreditacion VALUES ('AC006', 'AS011', 'AT004', '2026-07-25', 'Activa');
INSERT INTO Acreditacion VALUES ('AC007', 'AS012', 'AT004', '2026-07-25', 'Activa');
INSERT INTO Acreditacion VALUES ('AC008', 'AS013', 'AT004', '2026-07-25', 'Activa');
INSERT INTO Acreditacion VALUES ('AC009', 'AS014', 'AT004', '2026-07-25', 'Activa');

INSERT INTO Alojamiento VALUES ('AL001', 'Hotel Centro', '301', '2026-08-07', '2026-08-16', 'AS006');
INSERT INTO Alojamiento VALUES ('AL002', 'Hotel Centro', '302', '2026-08-07', '2026-08-16', 'AS010');
INSERT INTO Alojamiento VALUES ('AL003', 'Hotel Plaza', '210', '2026-08-08', '2026-08-15', 'AS011');
INSERT INTO Alojamiento VALUES ('AL004', 'Hotel Plaza', '211', '2026-08-08', '2026-08-15', 'AS012');
INSERT INTO Alojamiento VALUES ('AL005', 'Hotel Plaza', '212', '2026-08-08', '2026-08-15', 'AS013');

INSERT INTO Traslados VALUES ('TR001', 'Aeropuerto Viru Viru', 'Hotel Centro', 'Van', '2026-08-07T09:30:00', 'Llegada invitado VIP', 'AS006');
INSERT INTO Traslados VALUES ('TR002', 'Hotel Centro', 'Cinemateca Central', 'Auto', '2026-08-10T17:00:00', 'Traslado a proyeccion especial', 'AS010');
INSERT INTO Traslados VALUES ('TR003', 'Aeropuerto Viru Viru', 'Hotel Plaza', 'Van', '2026-08-08T10:15:00', 'Llegada jurado', 'AS011');
INSERT INTO Traslados VALUES ('TR004', 'Hotel Plaza', 'Centro Cultural Oriente', 'Auto', '2026-08-11T14:00:00', 'Traslado a evaluacion', 'AS012');

INSERT INTO Compra VALUES ('CO001', '2026-08-01T09:15:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO002', '2026-08-01T10:00:00', 'Efectivo', 'ED003');
INSERT INTO Compra VALUES ('CO003', '2026-08-02T11:20:00', 'QR', 'ED003');
INSERT INTO Compra VALUES ('CO004', '2026-08-02T12:35:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO005', '2026-08-03T13:40:00', 'QR', 'ED003');
INSERT INTO Compra VALUES ('CO006', '2026-08-03T14:10:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO007', '2026-08-04T15:00:00', 'Efectivo', 'ED003');
INSERT INTO Compra VALUES ('CO008', '2026-08-04T16:25:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO009', '2026-08-05T17:30:00', 'QR', 'ED003');
INSERT INTO Compra VALUES ('CO010', '2026-08-05T18:10:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO011', '2026-08-06T09:50:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO012', '2026-08-06T10:45:00', 'QR', 'ED003');
INSERT INTO Compra VALUES ('CO013', '2026-08-06T11:30:00', 'Efectivo', 'ED003');
INSERT INTO Compra VALUES ('CO014', '2026-08-07T12:15:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO015', '2026-08-07T13:05:00', 'QR', 'ED003');
INSERT INTO Compra VALUES ('CO016', '2026-08-07T15:00:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO017', '2026-08-07T16:00:00', 'QR', 'ED003');
INSERT INTO Compra VALUES ('CO018', '2026-08-07T17:00:00', 'Tarjeta', 'ED003');
INSERT INTO Compra VALUES ('CO019', '2026-08-08T09:00:00', 'Transferencia', 'ED003');
INSERT INTO Compra VALUES ('CO020', '2026-08-08T10:00:00', 'Efectivo', 'ED003');

INSERT INTO Tarifas VALUES ('TA001', 'General', 50.00, 'Tarifa general para publico.');
INSERT INTO Tarifas VALUES ('TA002', 'Estudiante', 30.00, 'Tarifa con descuento estudiantil.');
INSERT INTO Tarifas VALUES ('TA003', 'Jubilado', 25.00, 'Tarifa preferencial para jubilados.');
INSERT INTO Tarifas VALUES ('TA004', 'Acreditado', 0.00, 'Acceso gratuito para acreditados seleccionados.');
INSERT INTO Tarifas VALUES ('TA005', 'VIP', 0.00, 'Acceso especial VIP.');

INSERT INTO Factura VALUES ('FA001', '123456701', 'Camila Flores', 50.00, 'CO001');
INSERT INTO Factura VALUES ('FA002', '123456702', 'Andres Molina', 30.00, 'CO002');
INSERT INTO Factura VALUES ('FA003', '123456703', 'Paula Castro', 50.00, 'CO003');
INSERT INTO Factura VALUES ('FA004', '123456704', 'Daniela Soto', 50.00, 'CO004');
INSERT INTO Factura VALUES ('FA005', '123456705', 'Mariana Lopez', 120.00, 'CO005');
INSERT INTO Factura VALUES ('FA006', '123456706', 'Rodrigo Vega', 200.00, 'CO006');
INSERT INTO Factura VALUES ('FA007', '123456707', 'Daniela Soto', 60.00, 'CO007');
INSERT INTO Factura VALUES ('FA008', '123456708', 'Javier Paredes', 0.00, 'CO008');
INSERT INTO Factura VALUES ('FA009', '123456709', 'Gabriel Torres', 0.00, 'CO009');
INSERT INTO Factura VALUES ('FA010', '123456710', 'Renata Ibarra', 0.00, 'CO010');
INSERT INTO Factura VALUES ('FA011', '123456711', 'Nicolas Rivas', 50.00, 'CO011');
INSERT INTO Factura VALUES ('FA012', '123456712', 'Elena Morales', 30.00, 'CO012');
INSERT INTO Factura VALUES ('FA013', '123456713', 'Camila Flores', 50.00, 'CO013');
INSERT INTO Factura VALUES ('FA014', '123456714', 'Andres Molina', 30.00, 'CO014');
INSERT INTO Factura VALUES ('FA015', '123456715', 'Adriana Ribera', 50.00, 'CO015');
INSERT INTO Factura VALUES ('FA016', '123456716', 'Samuel Luna', 50.00, 'CO016');
INSERT INTO Factura VALUES ('FA017', '123456717', 'Isabel Mamani', 30.00, 'CO017');
INSERT INTO Factura VALUES ('FA018', '123456718', 'Tomas Gutierrez', 0.00, 'CO018');
INSERT INTO Factura VALUES ('FA019', '123456719', 'Silvia Campos', 0.00, 'CO019');
INSERT INTO Factura VALUES ('FA020', '123456720', 'Oscar Benitez', 50.00, 'CO020');

INSERT INTO TipoAbono VALUES ('TB001', 'Abono Fin de Semana', 'Acceso a proyecciones seleccionadas de fin de semana.', 120.00);
INSERT INTO TipoAbono VALUES ('TB002', 'Abono Total', 'Acceso total a las proyecciones de la edicion actual.', 200.00);
INSERT INTO TipoAbono VALUES ('TB003', 'Abono Prensa', 'Abono gratuito para prensa acreditada.', 0.00);
INSERT INTO TipoAbono VALUES ('TB004', 'Abono VIP', 'Acceso preferencial para invitados VIP.', 0.00);
INSERT INTO TipoAbono VALUES ('TB005', 'Abono Jurado', 'Acceso total para miembros del jurado.', 0.00);

INSERT INTO Abono VALUES ('AB001', 'AB-2026-001', 120.00, 'Activo', 'CO005', 'AS005', 'TB001', 'TA001');
INSERT INTO Abono VALUES ('AB002', 'AB-2026-002', 200.00, 'Activo', 'CO006', 'AS006', 'TB002', 'TA001');
INSERT INTO Abono VALUES ('AB003', 'AB-2026-003', 0.00, 'Activo', 'CO008', 'AS004', 'TB003', 'TA004');
INSERT INTO Abono VALUES ('AB004', 'AB-2026-004', 0.00, 'Activo', 'CO009', 'AS010', 'TB004', 'TA005');
INSERT INTO Abono VALUES ('AB005', 'AB-2026-005', 0.00, 'Activo', 'CO010', 'AS011', 'TB005', 'TA005');

INSERT INTO AbonoProyeccion VALUES ('AB001', 'PR001');
INSERT INTO AbonoProyeccion VALUES ('AB001', 'PR002');
INSERT INTO AbonoProyeccion VALUES ('AB001', 'PR005');
INSERT INTO AbonoProyeccion VALUES ('AB002', 'PR001');
INSERT INTO AbonoProyeccion VALUES ('AB002', 'PR003');
INSERT INTO AbonoProyeccion VALUES ('AB002', 'PR004');
INSERT INTO AbonoProyeccion VALUES ('AB002', 'PR006');
INSERT INTO AbonoProyeccion VALUES ('AB003', 'PR003');
INSERT INTO AbonoProyeccion VALUES ('AB003', 'PR008');
INSERT INTO AbonoProyeccion VALUES ('AB004', 'PR005');
INSERT INTO AbonoProyeccion VALUES ('AB004', 'PR006');
INSERT INTO AbonoProyeccion VALUES ('AB004', 'PR007');
INSERT INTO AbonoProyeccion VALUES ('AB004', 'PR010');
INSERT INTO AbonoProyeccion VALUES ('AB005', 'PR001');
INSERT INTO AbonoProyeccion VALUES ('AB005', 'PR003');

INSERT INTO EntradasIndividuales VALUES ('EN001', 'EN-2026-001', 1, 50.00, 'CO001', 'PR001', NULL, 'AS001', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN002', 'EN-2026-002', 2, 30.00, 'CO002', 'PR001', NULL, 'AS002', 'TA002');
INSERT INTO EntradasIndividuales VALUES ('EN003', 'EN-2026-003', 3, 25.00, 'CO003', 'PR002', NULL, 'AS003', 'TA003');
INSERT INTO EntradasIndividuales VALUES ('EN004', 'EN-2026-004', 4, 50.00, 'CO004', 'PR002', NULL, 'AS007', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN005', 'EN-2026-005', 5, 50.00, 'CO011', 'PR003', NULL, 'AS008', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN006', 'EN-2026-006', 6, 30.00, 'CO012', 'PR003', NULL, 'AS009', 'TA002');
INSERT INTO EntradasIndividuales VALUES ('EN007', 'EN-2026-007', 7, 50.00, 'CO013', 'PR004', NULL, 'AS001', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN008', 'EN-2026-008', 8, 30.00, 'CO014', 'PR005', NULL, 'AS002', 'TA002');
INSERT INTO EntradasIndividuales VALUES ('EN009', 'EN-2026-009', 9, 50.00, 'CO015', 'PR005', NULL, 'AS015', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN010', 'EN-2026-010', 10, 25.00, 'CO003', 'PR006', NULL, 'AS003', 'TA003');
INSERT INTO EntradasIndividuales VALUES ('EN011', 'EN-2026-011', NULL, 60.00, 'CO007', NULL, 'EV002', 'AS007', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN012', 'EN-2026-012', NULL, 0.00, 'CO008', NULL, 'EV003', 'AS004', 'TA004');
INSERT INTO EntradasIndividuales VALUES ('EN013', 'EN-2026-013', 11, 50.00, 'CO016', 'PR007', NULL, 'AS012', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN014', 'EN-2026-014', 12, 30.00, 'CO017', 'PR008', NULL, 'AS013', 'TA002');
INSERT INTO EntradasIndividuales VALUES ('EN015', 'EN-2026-015', 13, 0.00, 'CO018', 'PR010', NULL, 'AS014', 'TA004');
INSERT INTO EntradasIndividuales VALUES ('EN016', 'EN-2026-016', 14, 50.00, 'CO020', 'PR010', NULL, 'AS016', 'TA001');
INSERT INTO EntradasIndividuales VALUES ('EN017', 'EN-2026-017', NULL, 0.00, 'CO019', NULL, 'EV001', 'AS017', 'TA004');

INSERT INTO AsistenciaProyeccion VALUES ('AP001', '2026-08-09T09:55:00', 1, 'PR001', 'AS001', 'EN001', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP002', '2026-08-09T09:56:00', 1, 'PR001', 'AS002', 'EN002', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP003', '2026-08-09T09:57:00', 1, 'PR001', 'AS005', NULL, 'AB001');
INSERT INTO AsistenciaProyeccion VALUES ('AP004', '2026-08-09T09:58:00', 1, 'PR001', 'AS006', NULL, 'AB002');
INSERT INTO AsistenciaProyeccion VALUES ('AP005', '2026-08-09T09:59:00', 1, 'PR001', 'AS011', NULL, 'AB005');
INSERT INTO AsistenciaProyeccion VALUES ('AP006', '2026-08-09T14:55:00', 1, 'PR002', 'AS003', 'EN003', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP007', '2026-08-09T14:56:00', 1, 'PR002', 'AS005', NULL, 'AB001');
INSERT INTO AsistenciaProyeccion VALUES ('AP008', '2026-08-10T18:50:00', 1, 'PR003', 'AS008', 'EN005', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP009', '2026-08-10T18:51:00', 1, 'PR003', 'AS009', 'EN006', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP010', '2026-08-10T18:52:00', 1, 'PR003', 'AS006', NULL, 'AB002');
INSERT INTO AsistenciaProyeccion VALUES ('AP011', '2026-08-10T18:53:00', 1, 'PR003', 'AS004', NULL, 'AB003');
INSERT INTO AsistenciaProyeccion VALUES ('AP012', '2026-08-10T18:54:00', 1, 'PR003', 'AS011', NULL, 'AB005');
INSERT INTO AsistenciaProyeccion VALUES ('AP013', '2026-08-11T10:55:00', 1, 'PR004', 'AS001', 'EN007', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP014', '2026-08-11T10:56:00', 1, 'PR004', 'AS006', NULL, 'AB002');
INSERT INTO AsistenciaProyeccion VALUES ('AP015', '2026-08-11T18:20:00', 1, 'PR005', 'AS002', 'EN008', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP016', '2026-08-11T18:21:00', 1, 'PR005', 'AS015', 'EN009', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP017', '2026-08-11T18:22:00', 1, 'PR005', 'AS005', NULL, 'AB001');
INSERT INTO AsistenciaProyeccion VALUES ('AP018', '2026-08-11T18:23:00', 1, 'PR005', 'AS010', NULL, 'AB004');
INSERT INTO AsistenciaProyeccion VALUES ('AP019', '2026-08-12T19:50:00', 1, 'PR006', 'AS003', 'EN010', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP020', '2026-08-12T19:51:00', 1, 'PR006', 'AS006', NULL, 'AB002');
INSERT INTO AsistenciaProyeccion VALUES ('AP021', '2026-08-12T19:52:00', 1, 'PR006', 'AS010', NULL, 'AB004');
INSERT INTO AsistenciaProyeccion VALUES ('AP022', '2026-08-13T15:55:00', 1, 'PR007', 'AS012', 'EN013', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP023', '2026-08-13T15:56:00', 1, 'PR007', 'AS010', NULL, 'AB004');
INSERT INTO AsistenciaProyeccion VALUES ('AP024', '2026-08-14T16:50:00', 1, 'PR008', 'AS013', 'EN014', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP025', '2026-08-14T16:51:00', 1, 'PR008', 'AS004', NULL, 'AB003');
INSERT INTO AsistenciaProyeccion VALUES ('AP026', '2026-08-15T19:50:00', 1, 'PR010', 'AS014', 'EN015', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP027', '2026-08-15T19:51:00', 1, 'PR010', 'AS016', 'EN016', NULL);
INSERT INTO AsistenciaProyeccion VALUES ('AP028', '2026-08-15T19:52:00', 1, 'PR010', 'AS010', NULL, 'AB004');

INSERT INTO Jurado VALUES ('JU001', 'Presente', 'Direccion', 'Experto', 'PE021');
INSERT INTO Jurado VALUES ('JU002', 'Presente', 'Guion', 'Critico', 'PE022');
INSERT INTO Jurado VALUES ('JU003', 'Presente', 'Fotografia', 'Director', 'PE023');
INSERT INTO Jurado VALUES ('JU004', 'Presente', 'Produccion', 'Experto', 'PE024');

INSERT INTO CategoriasCompeticion VALUES ('CC001', 'Mejor Cortometraje', 'Premia la mejor obra corta de la edicion.', 'ED003');
INSERT INTO CategoriasCompeticion VALUES ('CC002', 'Mejor Director', 'Reconoce la mejor direccion cinematografica.', 'ED003');
INSERT INTO CategoriasCompeticion VALUES ('CC003', 'Premio del Publico', 'Reconocimiento segun recepcion del publico.', 'ED003');

INSERT INTO CategoriaJurado VALUES ('CC001', 'JU001');
INSERT INTO CategoriaJurado VALUES ('CC001', 'JU002');
INSERT INTO CategoriaJurado VALUES ('CC002', 'JU002');
INSERT INTO CategoriaJurado VALUES ('CC002', 'JU003');
INSERT INTO CategoriaJurado VALUES ('CC002', 'JU004');
INSERT INTO CategoriaJurado VALUES ('CC003', 'JU001');
INSERT INTO CategoriaJurado VALUES ('CC003', 'JU004');

INSERT INTO PeliculaCompite VALUES ('CP001', 'Finalista', '2026-08-08', 'CC001', 'PX001');
INSERT INTO PeliculaCompite VALUES ('CP002', 'Finalista', '2026-08-08', 'CC001', 'PX002');
INSERT INTO PeliculaCompite VALUES ('CP003', 'Finalista', '2026-08-08', 'CC002', 'PX003');
INSERT INTO PeliculaCompite VALUES ('CP004', 'Finalista', '2026-08-08', 'CC002', 'PX004');
INSERT INTO PeliculaCompite VALUES ('CP005', 'Finalista', '2026-08-08', 'CC003', 'PX005');
INSERT INTO PeliculaCompite VALUES ('CP006', 'Finalista', '2026-08-08', 'CC003', 'PX008');

INSERT INTO Evaluacion VALUES ('EA001', 8.50, 'Muy solida en estructura y propuesta.', '2026-08-13', 'JU001', 'CC001', 'CP001');
INSERT INTO Evaluacion VALUES ('EA002', 9.00, 'Gran sensibilidad narrativa.', '2026-08-13', 'JU002', 'CC001', 'CP001');
INSERT INTO Evaluacion VALUES ('EA003', 7.50, 'Buena idea con ritmo irregular.', '2026-08-13', 'JU001', 'CC001', 'CP002');
INSERT INTO Evaluacion VALUES ('EA004', 8.00, 'Interesante tratamiento social.', '2026-08-13', 'JU002', 'CC001', 'CP002');

INSERT INTO Evaluacion VALUES ('EA005', 9.00, 'Direccion madura y precisa.', '2026-08-14', 'JU002', 'CC002', 'CP003');
INSERT INTO Evaluacion VALUES ('EA006', 9.20, 'Excelente manejo visual.', '2026-08-14', 'JU003', 'CC002', 'CP003');
INSERT INTO Evaluacion VALUES ('EA007', 8.80, 'Gran direccion de actores.', '2026-08-14', 'JU004', 'CC002', 'CP003');
INSERT INTO Evaluacion VALUES ('EA008', 8.00, 'Correcta pero convencional.', '2026-08-14', 'JU002', 'CC002', 'CP004');
INSERT INTO Evaluacion VALUES ('EA009', 8.50, 'Buena atmosfera urbana.', '2026-08-14', 'JU003', 'CC002', 'CP004');
INSERT INTO Evaluacion VALUES ('EA010', 8.30, 'Propuesta visual consistente.', '2026-08-14', 'JU004', 'CC002', 'CP004');

INSERT INTO Evaluacion VALUES ('EA011', 9.50, 'Alta conexion emocional con el publico.', '2026-08-15', 'JU001', 'CC003', 'CP005');
INSERT INTO Evaluacion VALUES ('EA012', 9.00, 'Muy bien recibida en sala.', '2026-08-15', 'JU004', 'CC003', 'CP005');
INSERT INTO Evaluacion VALUES ('EA013', 8.00, 'Correcta y emotiva.', '2026-08-15', 'JU001', 'CC003', 'CP006');
INSERT INTO Evaluacion VALUES ('EA014', 8.50, 'Buena recepcion general.', '2026-08-15', 'JU004', 'CC003', 'CP006');

INSERT INTO Premio VALUES ('PM001', 'Mejor Cortometraje', '2026-08-16', 'CP001', 'CC001');
INSERT INTO Premio VALUES ('PM002', 'Mejor Director', '2026-08-16', 'CP003', 'CC002');
INSERT INTO Premio VALUES ('PM003', 'Premio del Publico', '2026-08-16', 'CP005', 'CC003');

GO

CREATE TRIGGER TR_ValidarFacturaMonto
ON Factura
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS
	(
		SELECT 1
		FROM inserted I
		CROSS APPLY
		(
			SELECT
				ISNULL((SELECT SUM(PrecioAplicado) FROM EntradasIndividuales WHERE IdCompra = I.IdCompra), 0)
				+
				ISNULL((SELECT SUM(PrecioAplicado) FROM Abono WHERE IdCompra = I.IdCompra), 0) AS TotalDetalle
		) AS X
		WHERE I.Monto <> X.TotalDetalle
	)
	BEGIN
		ROLLBACK TRANSACTION;
		RAISERROR('El monto de la factura no coincide con el total de entradas y abonos de la compra.', 16, 1);
		RETURN;
	END;
END;
GO

CREATE SEQUENCE SeqCompra
	AS INT
	START WITH 21
	INCREMENT BY 1;
GO

CREATE SEQUENCE SeqEntrada
	AS INT
	START WITH 18
	INCREMENT BY 1;
GO

CREATE SEQUENCE SeqFactura
	AS INT
	START WITH 21
	INCREMENT BY 1;
GO

CREATE SEQUENCE SeqAbono
	AS INT
	START WITH 6
	INCREMENT BY 1;
GO

CREATE SEQUENCE SeqAsistencia
	AS INT
	START WITH 29
	INCREMENT BY 1;
GO

CREATE PROCEDURE SP_ListarEdiciones
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		IdEdicion,
		NombreEdicion,
		FechaInicio,
		FechaFin,
		EstadoEdicion
	FROM Edicion
	ORDER BY FechaInicio DESC;
END;
GO

CREATE PROCEDURE SP_RankingPeliculasPorEdicion
	@IdEdicion CHAR(5)
AS
BEGIN
	SET NOCOUNT ON;

	WITH AsistenciaPorProyeccion AS
	(
		SELECT 
			IdProyeccion,
			COUNT(*) AS AsistentesReales
		FROM AsistenciaProyeccion
		WHERE Asistio = 1
		GROUP BY IdProyeccion
	)
	SELECT
		P.IdPelicula,
		P.Titulo,
		COUNT(PR.IdProyeccion) AS CantidadProyecciones,
		SUM(S.Capacidad) AS CapacidadTotal,
		ISNULL(SUM(APP.AsistentesReales), 0) AS AsistentesReales,
		CAST
		(
			ISNULL(SUM(APP.AsistentesReales), 0) * 100.0 
			/ NULLIF(SUM(S.Capacidad), 0)
			AS DECIMAL(5,2)
		) AS PorcentajeOcupacion
	FROM Proyecciones PR
	INNER JOIN PeliculaEdicion PE
		ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
	INNER JOIN Pelicula P
		ON PE.IdPelicula = P.IdPelicula
	INNER JOIN Salas S
		ON PR.IdSala = S.IdSala
	LEFT JOIN AsistenciaPorProyeccion APP
		ON PR.IdProyeccion = APP.IdProyeccion
	WHERE PE.IdEdicion = @IdEdicion
	GROUP BY
		P.IdPelicula,
		P.Titulo
	ORDER BY
		AsistentesReales DESC,
		PorcentajeOcupacion DESC;
END;
GO

CREATE PROCEDURE SP_ActaPremiacionPorEdicion
	@IdEdicion CHAR(5)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		CC.IdCategoria,
		CC.NombreCategoria,
		PM.NombrePremio,
		P.IdPelicula,
		P.Titulo,
		COUNT(E.IdEvaluacion) AS CantidadEvaluaciones,
		CAST(AVG(E.Puntuacion) AS DECIMAL(4,2)) AS PromedioVotacion
	FROM Premio PM
	INNER JOIN PeliculaCompite PC
		ON PM.IdCompetencia = PC.IdCompetencia
		AND PM.IdCategoria = PC.IdCategoria
	INNER JOIN CategoriasCompeticion CC
		ON PC.IdCategoria = CC.IdCategoria
	INNER JOIN PeliculaEdicion PE
		ON PC.IdPeliculaEdicion = PE.IdPeliculaEdicion
	INNER JOIN Pelicula P
		ON PE.IdPelicula = P.IdPelicula
	LEFT JOIN Evaluacion E
		ON PC.IdCompetencia = E.IdCompetencia
		AND PC.IdCategoria = E.IdCategoria
	WHERE CC.IdEdicion = @IdEdicion
	GROUP BY
		CC.IdCategoria,
		CC.NombreCategoria,
		PM.NombrePremio,
		P.IdPelicula,
		P.Titulo
	ORDER BY
		CC.NombreCategoria;
END;
GO

CREATE PROCEDURE SP_InformeFinancieroPorEdicion
	@IdEdicion CHAR(5)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		Ventas.TipoVenta,
		Ventas.SubtipoVenta,
		Ventas.TipoTarifa,
		COUNT(Ventas.IdVenta) AS CantidadVentas,
		SUM(Ventas.Monto) AS TotalRecaudado
	FROM
	(
		SELECT
			'Entrada Individual' AS TipoVenta,
			CASE
				WHEN EI.IdProyeccion IS NOT NULL THEN 'Proyeccion'
				WHEN EI.IdEvento IS NOT NULL THEN 'Evento Paralelo'
				ELSE 'Sin Destino'
			END AS SubtipoVenta,
			EI.IdEntrada AS IdVenta,
			T.TipoTarifa,
			EI.PrecioAplicado AS Monto
		FROM EntradasIndividuales EI
		INNER JOIN Compra C
			ON EI.IdCompra = C.IdCompra
		INNER JOIN Tarifas T
			ON EI.IdTarifa = T.IdTarifa
		WHERE C.IdEdicion = @IdEdicion

		UNION ALL

		SELECT
			'Abono' AS TipoVenta,
			TA.NombreTipoAbono AS SubtipoVenta,
			A.IdAbono AS IdVenta,
			T.TipoTarifa,
			A.PrecioAplicado AS Monto
		FROM Abono A
		INNER JOIN Compra C
			ON A.IdCompra = C.IdCompra
		INNER JOIN Tarifas T
			ON A.IdTarifa = T.IdTarifa
		INNER JOIN TipoAbono TA
			ON A.IdTipoAbono = TA.IdTipoAbono
		WHERE C.IdEdicion = @IdEdicion
	) AS Ventas
	GROUP BY
		Ventas.TipoVenta,
		Ventas.SubtipoVenta,
		Ventas.TipoTarifa
	ORDER BY
		Ventas.TipoVenta,
		Ventas.SubtipoVenta,
		Ventas.TipoTarifa;
END;
GO

CREATE PROCEDURE SP_ComprarEntrada
	@IdAsistente CHAR(5),
	@IdProyeccion CHAR(5),
	@IdTarifa CHAR(5),
	@MetodoPago VARCHAR(50),
	@NIT VARCHAR(20) = NULL,
	@NombreCompra VARCHAR(80),
	@NroAsiento INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IdEdicion CHAR(5);
	DECLARE @Capacidad INT;
	DECLARE @Ocupados INT;
	DECLARE @Precio DECIMAL(10,2);
	DECLARE @TipoTarifa VARCHAR(30);

	DECLARE @IdCompra CHAR(5);
	DECLARE @IdEntrada CHAR(5);
	DECLARE @IdFactura CHAR(5);
	DECLARE @IdAsistencia CHAR(5);
	DECLARE @CodigoEntrada VARCHAR(30);

	DECLARE @NumCompra INT;
	DECLARE @NumEntrada INT;
	DECLARE @NumFactura INT;
	DECLARE @NumAsistencia INT;

	BEGIN TRY
		BEGIN TRANSACTION;

		SELECT 
			@IdEdicion = PE.IdEdicion,
			@Capacidad = S.Capacidad
		FROM Proyecciones PR WITH (UPDLOCK, HOLDLOCK)
		INNER JOIN PeliculaEdicion PE
			ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
		INNER JOIN Salas S
			ON PR.IdSala = S.IdSala
		WHERE PR.IdProyeccion = @IdProyeccion;

		IF @IdEdicion IS NULL
		BEGIN
			RAISERROR('La proyeccion indicada no existe.', 16, 1);
			RETURN;
		END;

		IF NOT EXISTS
		(
			SELECT 1
			FROM Asistentes
			WHERE IdAsistente = @IdAsistente
			  AND IdEdicion = @IdEdicion
		)
		BEGIN
			RAISERROR('El asistente no pertenece a la edicion de esta proyeccion.', 16, 1);
			RETURN;
		END;

		SELECT 
			@Precio = Precio,
			@TipoTarifa = TipoTarifa
		FROM Tarifas
		WHERE IdTarifa = @IdTarifa;

		IF @Precio IS NULL
		BEGIN
			RAISERROR('La tarifa indicada no existe.', 16, 1);
			RETURN;
		END;

		IF @TipoTarifa = 'Acreditado'
		BEGIN
			IF NOT EXISTS
			(
				SELECT 1
				FROM Acreditacion
				WHERE IdAsistente = @IdAsistente
				  AND EstadoAcreditacion = 'Activa'
			)
			BEGIN
				RAISERROR('La tarifa Acreditado requiere una acreditacion activa.', 16, 1);
				RETURN;
			END;
		END;

		IF @TipoTarifa = 'VIP'
		BEGIN
			IF NOT EXISTS
			(
				SELECT 1
				FROM Acreditacion AC
				INNER JOIN TipoAcreditacion TA
					ON AC.IdTipoAcreditacion = TA.IdTipoAcreditacion
				WHERE AC.IdAsistente = @IdAsistente
				  AND AC.EstadoAcreditacion = 'Activa'
				  AND TA.NombreTipo = 'VIP'
			)
			BEGIN
				RAISERROR('La tarifa VIP requiere acreditacion VIP activa.', 16, 1);
				RETURN;
			END;
		END;

		IF EXISTS
		(
			SELECT 1
			FROM EntradasIndividuales
			WHERE IdProyeccion = @IdProyeccion
			  AND IdAsistente = @IdAsistente
		)
		BEGIN
			RAISERROR('El asistente ya tiene una entrada individual para esta proyeccion.', 16, 1);
			RETURN;
		END;

		IF EXISTS
		(
			SELECT 1
			FROM AsistenciaProyeccion
			WHERE IdProyeccion = @IdProyeccion
			  AND IdAsistente = @IdAsistente
		)
		BEGIN
			RAISERROR('El asistente ya tiene registrado acceso o asistencia para esta proyeccion.', 16, 1);
			RETURN;
		END;

		SELECT @Ocupados =
		(
			SELECT COUNT(*)
			FROM EntradasIndividuales
			WHERE IdProyeccion = @IdProyeccion
		)
		+
		(
			SELECT COUNT(*)
			FROM AbonoProyeccion AP
			INNER JOIN Abono A
				ON AP.IdAbono = A.IdAbono
			WHERE AP.IdProyeccion = @IdProyeccion
			  AND A.EstadoAbono <> 'Anulado'
		);

		IF @Ocupados >= @Capacidad
		BEGIN
			RAISERROR('No hay aforo disponible para esta proyeccion.', 16, 1);
			RETURN;
		END;

		IF @NroAsiento IS NOT NULL
		BEGIN
			IF @NroAsiento <= 0 OR @NroAsiento > @Capacidad
			BEGIN
				RAISERROR('El numero de asiento no es valido para la capacidad de la sala.', 16, 1);
				RETURN;
			END;

			IF EXISTS
			(
				SELECT 1
				FROM EntradasIndividuales
				WHERE IdProyeccion = @IdProyeccion
				  AND NroAsiento = @NroAsiento
			)
			BEGIN
				RAISERROR('El asiento seleccionado ya fue vendido para esta proyeccion.', 16, 1);
				RETURN;
			END;
		END;

		SELECT @NumCompra = NEXT VALUE FOR SeqCompra;
		SELECT @NumEntrada = NEXT VALUE FOR SeqEntrada;
		SELECT @NumFactura = NEXT VALUE FOR SeqFactura;
		SELECT @NumAsistencia = NEXT VALUE FOR SeqAsistencia;

		IF @NumCompra > 999 OR @NumEntrada > 999 OR @NumFactura > 999 OR @NumAsistencia > 999
		BEGIN
			RAISERROR('Se alcanzo el limite de IDs CHAR(5) con formato de tres digitos.', 16, 1);
			RETURN;
		END;

		SET @IdCompra = 'CO' + RIGHT('000' + CAST(@NumCompra AS VARCHAR(3)), 3);
		SET @IdEntrada = 'EN' + RIGHT('000' + CAST(@NumEntrada AS VARCHAR(3)), 3);
		SET @IdFactura = 'FA' + RIGHT('000' + CAST(@NumFactura AS VARCHAR(3)), 3);
		SET @IdAsistencia = 'AP' + RIGHT('000' + CAST(@NumAsistencia AS VARCHAR(3)), 3);
		SET @CodigoEntrada = 'ENT-' + @IdEntrada;

		INSERT INTO Compra
		(
			IdCompra,
			FechaHoraCompra,
			MetodoPago,
			IdEdicion
		)
		VALUES
		(
			@IdCompra,
			GETDATE(),
			@MetodoPago,
			@IdEdicion
		);

		INSERT INTO EntradasIndividuales
		(
			IdEntrada,
			CodigoEntrada,
			NroAsiento,
			PrecioAplicado,
			IdCompra,
			IdProyeccion,
			IdEvento,
			IdAsistente,
			IdTarifa
		)
		VALUES
		(
			@IdEntrada,
			@CodigoEntrada,
			@NroAsiento,
			@Precio,
			@IdCompra,
			@IdProyeccion,
			NULL,
			@IdAsistente,
			@IdTarifa
		);

		INSERT INTO AsistenciaProyeccion
		(
			IdAsistencia,
			FechaHoraControl,
			Asistio,
			IdProyeccion,
			IdAsistente,
			IdEntrada,
			IdAbono
		)
		VALUES
		(
			@IdAsistencia,
			GETDATE(),
			1,
			@IdProyeccion,
			@IdAsistente,
			@IdEntrada,
			NULL
		);

		INSERT INTO Factura
		(
			IdFactura,
			NIT,
			NombreCompra,
			Monto,
			IdCompra
		)
		VALUES
		(
			@IdFactura,
			@NIT,
			@NombreCompra,
			@Precio,
			@IdCompra
		);

		COMMIT TRANSACTION;

		SELECT 
			@IdCompra AS IdCompra,
			@IdEntrada AS IdEntrada,
			@IdFactura AS IdFactura,
			@CodigoEntrada AS CodigoEntrada,
			@Precio AS MontoPagado;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

		DECLARE @MensajeError NVARCHAR(4000);
		SET @MensajeError = ERROR_MESSAGE();

		RAISERROR(@MensajeError, 16, 1);
		RETURN;
	END CATCH;
END;
GO

CREATE PROCEDURE SP_VenderAbono
	@IdAsistente CHAR(5),
	@IdTipoAbono CHAR(5),
	@IdTarifa CHAR(5),
	@MetodoPago VARCHAR(50),
	@NIT VARCHAR(20) = NULL,
	@NombreCompra VARCHAR(80),
	@PagoAprobado BIT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IdEdicion CHAR(5);
	DECLARE @PrecioBase DECIMAL(10,2);
	DECLARE @PrecioTarifa DECIMAL(10,2);
	DECLARE @PrecioAplicado DECIMAL(10,2);
	DECLARE @NombreTipoAbono VARCHAR(50);
	DECLARE @TipoTarifa VARCHAR(30);

	DECLARE @IdCompra CHAR(5);
	DECLARE @IdAbono CHAR(5);
	DECLARE @IdFactura CHAR(5);
	DECLARE @CodigoAbono VARCHAR(30);

	DECLARE @NumCompra INT;
	DECLARE @NumAbono INT;
	DECLARE @NumFactura INT;

	DECLARE @ProyeccionesAsignadas TABLE
	(
		IdProyeccion CHAR(5) PRIMARY KEY
	);

	BEGIN TRY
		BEGIN TRANSACTION;

		IF @PagoAprobado = 0
		BEGIN
			RAISERROR('La pasarela de pago rechazo la transaccion.', 16, 1);
			RETURN;
		END;

		SELECT @IdEdicion = IdEdicion
		FROM Asistentes
		WHERE IdAsistente = @IdAsistente;

		IF @IdEdicion IS NULL
		BEGIN
			RAISERROR('El asistente indicado no existe.', 16, 1);
			RETURN;
		END;

		SELECT
			@PrecioBase = PrecioBase,
			@NombreTipoAbono = NombreTipoAbono
		FROM TipoAbono
		WHERE IdTipoAbono = @IdTipoAbono;

		IF @PrecioBase IS NULL
		BEGIN
			RAISERROR('El tipo de abono indicado no existe.', 16, 1);
			RETURN;
		END;

		SELECT 
			@PrecioTarifa = Precio,
			@TipoTarifa = TipoTarifa
		FROM Tarifas
		WHERE IdTarifa = @IdTarifa;

		IF @PrecioTarifa IS NULL
		BEGIN
			RAISERROR('La tarifa indicada no existe.', 16, 1);
			RETURN;
		END;

		IF @TipoTarifa = 'Acreditado'
		BEGIN
			IF NOT EXISTS
			(
				SELECT 1
				FROM Acreditacion
				WHERE IdAsistente = @IdAsistente
				  AND EstadoAcreditacion = 'Activa'
			)
			BEGIN
				RAISERROR('La tarifa Acreditado requiere una acreditacion activa.', 16, 1);
				RETURN;
			END;
		END;

		IF @TipoTarifa = 'VIP'
		BEGIN
			IF NOT EXISTS
			(
				SELECT 1
				FROM Acreditacion AC
				INNER JOIN TipoAcreditacion TA
					ON AC.IdTipoAcreditacion = TA.IdTipoAcreditacion
				WHERE AC.IdAsistente = @IdAsistente
				  AND AC.EstadoAcreditacion = 'Activa'
				  AND TA.NombreTipo = 'VIP'
			)
			BEGIN
				RAISERROR('La tarifa VIP requiere acreditacion VIP activa.', 16, 1);
				RETURN;
			END;
		END;

		IF @PrecioTarifa = 0
			SET @PrecioAplicado = 0;
		ELSE
			SET @PrecioAplicado = @PrecioBase;

		IF @NombreTipoAbono = 'Abono Fin de Semana'
		BEGIN
			INSERT INTO @ProyeccionesAsignadas(IdProyeccion)
			SELECT PR.IdProyeccion
			FROM Proyecciones PR
			INNER JOIN PeliculaEdicion PE
				ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
			WHERE PE.IdEdicion = @IdEdicion
			  AND PE.EstadoFestival IN ('Seleccionada', 'Premiada')
			  AND DATEDIFF(DAY, '19000101', CAST(PR.FechaHoraInicio AS DATE)) % 7 IN (5, 6);
		END;
		ELSE IF @NombreTipoAbono = 'Abono Total'
		BEGIN
			INSERT INTO @ProyeccionesAsignadas(IdProyeccion)
			SELECT PR.IdProyeccion
			FROM Proyecciones PR
			INNER JOIN PeliculaEdicion PE
				ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
			WHERE PE.IdEdicion = @IdEdicion
			  AND PE.EstadoFestival IN ('Seleccionada', 'Premiada');
		END;
		ELSE IF @NombreTipoAbono = 'Abono Prensa'
		BEGIN
			INSERT INTO @ProyeccionesAsignadas(IdProyeccion)
			SELECT PR.IdProyeccion
			FROM Proyecciones PR
			INNER JOIN PeliculaEdicion PE
				ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
			WHERE PE.IdEdicion = @IdEdicion
			  AND PE.EstadoFestival IN ('Seleccionada', 'Premiada')
			  AND PR.TieneQA = 1;
		END;
		ELSE IF @NombreTipoAbono = 'Abono VIP'
		BEGIN
			INSERT INTO @ProyeccionesAsignadas(IdProyeccion)
			SELECT PR.IdProyeccion
			FROM Proyecciones PR
			INNER JOIN PeliculaEdicion PE
				ON PR.IdPeliculaEdicion = PE.IdPeliculaEdicion
			WHERE PE.IdEdicion = @IdEdicion
			  AND PE.EstadoFestival = 'Premiada';
		END;
		ELSE IF @NombreTipoAbono = 'Abono Jurado'
		BEGIN
			INSERT INTO @ProyeccionesAsignadas(IdProyeccion)
			SELECT DISTINCT PR.IdProyeccion
			FROM Proyecciones PR
			INNER JOIN PeliculaCompite PC
				ON PR.IdPeliculaEdicion = PC.IdPeliculaEdicion
			INNER JOIN CategoriasCompeticion CC
				ON PC.IdCategoria = CC.IdCategoria
			WHERE CC.IdEdicion = @IdEdicion;
		END;
		ELSE
		BEGIN
			RAISERROR('El tipo de abono no tiene una regla de asignacion definida.', 16, 1);
			RETURN;
		END;

		IF NOT EXISTS (SELECT 1 FROM @ProyeccionesAsignadas)
		BEGIN
			RAISERROR('No existen proyecciones disponibles para generar el abono.', 16, 1);
			RETURN;
		END;

		IF EXISTS
		(
			SELECT 1
			FROM @ProyeccionesAsignadas PA
			INNER JOIN Proyecciones PR WITH (UPDLOCK, HOLDLOCK)
				ON PA.IdProyeccion = PR.IdProyeccion
			INNER JOIN Salas S
				ON PR.IdSala = S.IdSala
			CROSS APPLY
			(
				SELECT
				(
					SELECT COUNT(*)
					FROM EntradasIndividuales EI
					WHERE EI.IdProyeccion = PA.IdProyeccion
				)
				+
				(
					SELECT COUNT(*)
					FROM AbonoProyeccion AP
					INNER JOIN Abono A
						ON AP.IdAbono = A.IdAbono
					WHERE AP.IdProyeccion = PA.IdProyeccion
					  AND A.EstadoAbono <> 'Anulado'
				) AS Ocupados
			) AS X
			WHERE X.Ocupados >= S.Capacidad
		)
		BEGIN
			RAISERROR('Una o mas proyecciones del abono ya no tienen aforo disponible.', 16, 1);
			RETURN;
		END;

		SELECT @NumCompra = NEXT VALUE FOR SeqCompra;
		SELECT @NumAbono = NEXT VALUE FOR SeqAbono;
		SELECT @NumFactura = NEXT VALUE FOR SeqFactura;

		IF @NumCompra > 999 OR @NumAbono > 999 OR @NumFactura > 999
		BEGIN
			RAISERROR('Se alcanzo el limite de IDs CHAR(5) con formato de tres digitos.', 16, 1);
			RETURN;
		END;

		SET @IdCompra = 'CO' + RIGHT('000' + CAST(@NumCompra AS VARCHAR(3)), 3);
		SET @IdAbono = 'AB' + RIGHT('000' + CAST(@NumAbono AS VARCHAR(3)), 3);
		SET @IdFactura = 'FA' + RIGHT('000' + CAST(@NumFactura AS VARCHAR(3)), 3);
		SET @CodigoAbono = 'ABN-' + @IdAbono;

		INSERT INTO Compra
		(
			IdCompra,
			FechaHoraCompra,
			MetodoPago,
			IdEdicion
		)
		VALUES
		(
			@IdCompra,
			GETDATE(),
			@MetodoPago,
			@IdEdicion
		);

		INSERT INTO Abono
		(
			IdAbono,
			CodigoAbono,
			PrecioAplicado,
			EstadoAbono,
			IdCompra,
			IdAsistente,
			IdTipoAbono,
			IdTarifa
		)
		VALUES
		(
			@IdAbono,
			@CodigoAbono,
			@PrecioAplicado,
			'Activo',
			@IdCompra,
			@IdAsistente,
			@IdTipoAbono,
			@IdTarifa
		);

		INSERT INTO AbonoProyeccion
		(
			IdAbono,
			IdProyeccion
		)
		SELECT
			@IdAbono,
			IdProyeccion
		FROM @ProyeccionesAsignadas;

		INSERT INTO Factura
		(
			IdFactura,
			NIT,
			NombreCompra,
			Monto,
			IdCompra
		)
		VALUES
		(
			@IdFactura,
			@NIT,
			@NombreCompra,
			@PrecioAplicado,
			@IdCompra
		);

		COMMIT TRANSACTION;

		SELECT
			@IdCompra AS IdCompra,
			@IdAbono AS IdAbono,
			@IdFactura AS IdFactura,
			@CodigoAbono AS CodigoAbono,
			@PrecioAplicado AS MontoPagado;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

		DECLARE @MensajeError NVARCHAR(4000);
		SET @MensajeError = ERROR_MESSAGE();

		RAISERROR(@MensajeError, 16, 1);
		RETURN;
	END CATCH;
END;
GO

select * from Persona
select * from Asistentes
select * from AsistenciaProyeccion
select * from AbonoProyeccion
select * from Abono
select * from TipoAbono
select * from Acreditacion
select * from TipoAcreditacion
select * from Tarifas
