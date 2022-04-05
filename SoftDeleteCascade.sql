
-- Procedure que monta e executa script de exclusao lógica das tabelas em cascata a partir da tabela passada por parâmetro
Create PROCEDURE   [dbo].[sp_SoftDeleteCascade]
  @Tabela    nvarchar(512),
  @Coluna    sysname,
  @Condicao  nvarchar(255)
AS
BEGIN TRAN deleteCascade;
	SET NOCOUNT ON;
	DECLARE @ret_code int,
			@sql nvarchar(max) = N'',
			@src nvarchar(max) = N'UPDATE $tabela$ SET Excluido = 1 WHERE $coluna$ $condicao$;';
  
	;with cte_getTables(nomeTabela, chaveTabela) as
	(
		SELECT tabelas = QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)),  
			   chaves  = QUOTENAME(pc.name)
		FROM sys.foreign_key_columns AS fk
		INNER JOIN sys.columns AS pc       ON fk.parent_object_id     = pc.[object_id]  AND fk.parent_column_id     = pc.column_id
		INNER JOIN sys.columns AS rc       ON fk.referenced_column_id = rc.column_id    AND fk.referenced_object_id = rc.[object_id]
	)
	SELECT @sql = @sql + REPLACE(REPLACE(REPLACE(@src,N'$tabela$',cte_getTables.nomeTabela),N'$coluna$',cte_getTables.chaveTabela),N'$condicao$',@Condicao) 
	from cte_getTables
		
	SELECT @sql += REPLACE(REPLACE(REPLACE(@src,N'$tabela$',@Tabela),  N'$coluna$',@Coluna),N'$condicao$',@Condicao);

BEGIN TRY 
	EXEC @ret_code = sys.sp_executesql @sql;	
	COMMIT TRAN deleteCascade;
	RETURN(@ret_code) 
END TRY
BEGIN CATCH	
	ROLLBACK TRAN
	RETURN('error')
END CATCH
GO

-- Criacao e popula tabelas para teste da procedure a cima
IF OBJECT_ID('Empresas') IS NULL 
	CREATE TABLE Empresas (
	  Id    INT PRIMARY KEY,
	  Nome  VARCHAR(255),
	  CNPJ  VARCHAR(14),	  
	  Excluido BIT DEFAULT(0)
	);
GO

IF OBJECT_ID('Funcionarios') IS NULL 
BEGIN
	CREATE TABLE Funcionarios (
	  Id    INT PRIMARY KEY,
	  EmpresaId INT,
	  Nome  VARCHAR(255),
	  CPF   VARCHAR(11),
	  DataNascimento DATE,
	  Excluido BIT DEFAULT(0)
	);
	ALTER TABLE [dbo].[Funcionarios]  
	WITH CHECK ADD  CONSTRAINT [FK_Empresas_Funcionario] FOREIGN KEY([EmpresaId])
	REFERENCES [dbo].[Empresas] ([Id])
END
GO

IF OBJECT_ID('Dependentes') IS NULL 
BEGIN
	CREATE TABLE Dependentes (
	  Id    INT PRIMARY KEY,
	  FuncionarioId INT,
	  Nome  VARCHAR(255),
	  Parentesco VARCHAR(255),
	  Excluido BIT DEFAULT(0)  
	);
	ALTER TABLE [dbo].[Dependentes]  
	WITH CHECK ADD  CONSTRAINT [FK_Funcionarios_Dependente] FOREIGN KEY([FuncionarioId])
	REFERENCES [dbo].[Funcionarios] ([Id])
END
GO

IF OBJECT_ID('Contatos') IS NULL 
BEGIN
	CREATE TABLE Contatos (
	  Id    INT PRIMARY KEY,
	  FuncionarioId INT,
	  Telefone VARCHAR(13) NULL,
	  Excluido BIT DEFAULT(0)  
	);
	ALTER TABLE [dbo].[Contatos]  WITH CHECK ADD  CONSTRAINT [FK_Funcionarios_Contato] FOREIGN KEY([FuncionarioId])
	REFERENCES [dbo].[Funcionarios] ([Id])
END
GO

IF NOT EXISTS ( SELECT * FROM Empresas WHERE  Id < 4 ) 
BEGIN	
	INSERT INTO Empresas VALUES (1, 'Empresa 01','47644256000103',0);
	INSERT INTO Empresas VALUES (2, 'Empresa 02','78896439000131',0);	
END
GO

IF NOT EXISTS ( SELECT * FROM Funcionarios WHERE  Id < 4 ) 
BEGIN	
	INSERT INTO Funcionarios VALUES (1, 1,'Funcionario 01','56828259009','01/01/2000',0);
	INSERT INTO Funcionarios VALUES (2, 1,'Funcionario 02','50720977061','02/01/2000',0);
	INSERT INTO Funcionarios VALUES (3, 2,'Funcionario 03','79866200051','03/01/2000',0);
END
GO

IF NOT EXISTS ( SELECT * FROM Dependentes WHERE  Id < 5 ) 
BEGIN	
	INSERT INTO Dependentes VALUES (1, 1,'Dependente 01','Filho',0);
	INSERT INTO Dependentes VALUES (2, 1,'Dependente 02','Pai',0);
	INSERT INTO Dependentes VALUES (3, 1,'Dependente 03','Irmao',0);

	INSERT INTO Dependentes VALUES (4, 2,'Dependente 04','Filho',0);
	INSERT INTO Dependentes VALUES (5, 2,'Dependente 05','Esposa',0);	
END
GO

IF NOT EXISTS ( SELECT * FROM Contatos WHERE  Id < 5 ) 
BEGIN	
	INSERT INTO Contatos VALUES (1, 1,'(35)991111111',0);
	INSERT INTO Contatos VALUES (2, 1,'(35)992222222',0);

	INSERT INTO Contatos VALUES (3, 2,'(35)993333333',0);
	INSERT INTO Contatos VALUES (4, 2,'(35)994444444',0);
	INSERT INTO Contatos VALUES (5, 2,'(35)995555555',0);	
END
GO

-- executa a exclusao da empresa de id=1
exec dbo.[sp_SoftDeleteCascade] 'empresas', 'ID', '= 1'
GO

-- conferencia das tabelas com registros excluidos em cascata pela procedure sp_SoftDeleteCascade
SELECT * FROM Empresas
SELECT * FROM Funcionarios
SELECT * FROM Dependentes
SELECT * FROM Contatos