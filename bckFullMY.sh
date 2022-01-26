#!/bin/sh
# Para executar o backup do MySQL Ã© interessante criar um usuÃ¡rio especifico para isso
# Dentro do MySQL crie o usuÃ¡rio com esse comando
# CREATE USER 'mysqlbackup'@'localhost' IDENTIFIED BY '01020304';
#
# Depois de os seguintes privilegios para ele
# GRANT EVENT, SELECT, SHOW DATABASES, SHOW VIEW, LOCK TABLES, RELOAD, REPLICATION CLIENT ON *.* TO 'mysqlbackup'@'localhost';
#

# DEFININDO VARIÃVEIS ------------------------------------------------------------------------------------
USERNAME=`whoami`						# UsuÃ¡rio que estÃ¡ rodando o script
DATABASE_USER='mysqlbackup'				# UsuÃ¡rio do banco de dados
DATABASE_PWD='01020304'					# Senha do usuÃ¡rio do banco de dados
DATA_HOJE=`date +%Y%m%d_%H%M%S`			# Data de Hoje
NAME_PROG=`basename $0`					# Nome do script completo
SCRIPT=`echo $PROG | sed 's/\.sh$//'`	# Nome do script sem a extenÃ§Ã£o
TMP_LOG=""								# Armazena o LOG do script
DIR_PROG=`dirname $0`
DIR_PROG=`cd $DIR_PROG; pwd`			# DiretÃ³rio do script
DIR_LOG=$DIR_PROG/log					# DiretÃ³rio do LOG
LOG=$DIR_LOG/$SCRIPT_$DATA_HOJE.log		# Arquivo de LOG
TMP_PID=/var/tmp/$SCRIPT.pid			# PID do script
DIR_DESTINO='/home/davi/backups'		# DiretÃ³rio de destino do backup
DIR_PG='/usr/bin'						# DiretÃ³rio base do MySQL

# FUNÃ‡ÃƒO DO FINAL DO SCRIPT ------------------------------------------------------------------------------
fn_fim_script()
{
	cat > $TMP_LOG <<EOT

Fim do script de backup - script $PROG
Data/Hora: `date +%Y%m%d_%H%M%S`
EOT
}

# FUNÃ‡ÃƒO DE ERRO DO SCRIPT -------------------------------------------------------------------------------
fn_erro()
{
	SAIR=$1
	shift
	case $SAIR in
		[sSyY]*|1)
			echo "$PROG ERRO : $*" >&2
			[ -f $TMP_LOG ] && echo "##### $PROG ERRO : $*" >> $TMP_LOG
			fn_fim_script
			exit 1 ;;
	*)
		echo "$PROG Aviso: $*" >&2
		echo "##### $PROG Aviso: $*" >> $TMP_LOG ;;
	esac

}

# FUNÃ‡ÃƒO DE INTERRUPÃ‡ÃƒO ----------------------------------------------------------------------------------
fn_trap()
{
	fn_erro N "Script interrompido em `date`"
	fn_fim_script
	exit 2
}


# PROGRAMA PRINCIPAL -------------------------------------------------------------------------------------
# 01 Verifica se existe outro instÃ¢ncia do script --------------------------------------------------------

if [ -s $TMP_PID ]; then
	PID=`cat $TMP_PID`
	if ps -p $PID 2> /dev/null >&2; then
		echo "$PROG: Outra instancia em execucao PID=$PID em `date`" >&2
		exit 3
	fi
fi
echo $$ > $TMP_PID

# 02 Verifica qual o usuÃ¡rio estÃ¡ executando (somente o root pode executar) ------------------------------
if [ $USERNAME != "root" ]; then
	fn_erro S "Este programa sÃ³ pode ser executado pelo usuÃ¡rio root - TESTE"
fi

# 03 Impede a interruÃ§Ã£o por HANGUP (1), INTERRUPT (2) e TERMINATE (15) ----------------------------------
trap "fn_trap" 1 2 15

# 04 Verifica se o diretÃ³rio destino do backup existe
if ! [ -d $DIR_DESTINO ]; then
	mkdir $DIR_DESTINO
fi

# 05 Verifica se o diretÃ³rio do LOG existe
if ! [ -d $DIR_LOG ]; then
	mkdir $DIR_LOG
fi

(
# 06 Forma o cabeÃ§alho do LOG
cat <<EOT

======================================================================
BACKUP FULL MYSQL
$PROG INICIO: `date`
Servidor: `uname -n` 
----------------------------------------------------------------------
EOT

# 07 Carrega todas as bases de dados
# -N = skip-column-names
# -s = silent
# -r = raw - Write fields without conversion
$DIR_PROG/mysql -N -s -r -u $DATABASE_USER -p$DATABASE_PWD -e 'show databases' > $DIR_LOG/bancosBackupPG.dat

# 08 Loop com todas as bases de dados
while read NOME_BANCO
do 
	if [ "$NOME_BANCO" != "" ]; then
		# 09 Start with a try
		try
		( # open a subshell !!!
			# 09-01 Mensagem do LOG
			echo 
			echo Plano de manutencao:  $NOME_BANCO....

			#09-02 VariÃ¡veis do nome do backup
			NOME_DUMP=$DIR_BKP"/"$NOBANCO"_"$DATA_HOJE".dump"

			#09-03 Efetuando o backup
			$DIR_PROG/mysqldump -u $DATABASE_USER -p$DATABASE_PWD $NOBANCO > $NOME_DUMP

			# 09-04 Mensagem do LOG
			echo Backup $NOME_BANCO efetuado com Sucesso.
			
			# 09-05 Compacta o backup
			NOME_TAR=$DIR_BKP"/"$NOBANCO"_"$DATA_HOJE".tar.gz"
			/usr/bin/tar czvf $NOME_TAR $NOME_DUMP

			# 09-06 Remove o arquivo de backup
			rm -f $NOME_DUMP
		)
		# 10 Erro de execuÃ§Ã£o
		catch || {
			# 10-01 now you can handle
			case $ex_code in
				$AnException)
					echo "AnException was thrown"
					;;
				$AnotherException)
					echo "AnotherException was thrown"
					;;
				*)
					echo "An unexpected exception was thrown"
					throw $ex_code # you can rethrow the "exception" causing the script to exit if not caught
					;;
			esac
		}
	fi # NomeBanco
done < $DIR_LOG/bancosBackupPG.dat

cat <<EOT
----------------------------------------------------------------------
$PROG TERMINO: `date`

======================================================================
EOT
) >> $TMP_LOG 2>&1

fn_fim_script
exit 0
