#define PRGNAME "InfToD64"
#define PRGVERSION "3.02"
#define PRGDATE "22.5.2001"

#define NEWBAM 1

/*
 *  inftod64.c
 *
 *  - converts z-code datafile to D64 image(s)
 *
 *  needs inputfile "inftod64.dat" with the interpreter code!
 *
 *  infile:   Infocom datafile
 *            (V3: length <= 130560 bytes, V5: length <= 219136 bytes)
 *  outfile:  D64 disk image of an Infocom game
 *            (runs on real C64 and on emulators)
 *  outfile2: D64 disk image of second disk (only with V5)
 *
 *  Author: Paul David Doherty <42@pdd.de>
 *
 *  v1.0:    16 Feb 1996
 *  v1.01:   17 Feb 1996  stupid bug removed (thanks to Curtis White)
 *  v1.10:    4 Mar 1996  switched from interpreter 3G to 3H
 *  v2.0:    29 Jul 1996  completely rewritten, V5 added
 *  v2.0a:   24 Nov 1996  fixed lint warnings
 *  v2.1:     8 Aug 1997  datafile padding no longer transfered 
 *                        (suggested by Jason Compton)
 *  v3.0:     8 May 2001  some cleanups
 *  v3.01:   14 May 2001  FreeBSD patch supplied by Mcclain Looney
 *                        added DJGPP patches
 *  v3.02:   22 May 2001  small fix suggested by Miron Schmidt
 */

#if defined(AZTEC_C) || defined(LATTICE)
#define AMIGA
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <ctype.h>

#ifdef __TURBOC__
#include <io.h>
#include <sys\stat.h>
#define S_IRUSR S_IREAD
#define S_IWUSR S_IWRITE
#endif

#ifdef __GNUC__
#include <sys/stat.h>
#endif

#ifdef FREEBSD
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#endif

#ifdef __linux__
#include <unistd.h>
#endif

#ifdef __DJGPP__
#include <sys/types.h>
#include <io.h>
#include <unistd.h>
#endif

#ifndef S_IRUSR
#define S_IRUSR 0400
#define S_IWUSR 0200
#endif

#if defined(__TURBOC__) || defined(__DJGPP__) || (defined(__GNUC__) && !defined(__unix__))
#define O_SCRIVERE O_WRONLY|O_BINARY
#define O_LEGGERE O_RDONLY|O_BINARY
#else
#define O_SCRIVERE O_WRONLY
#define O_LEGGERE O_RDONLY
#endif

#define TRUE 1
#define FALSE 0

typedef unsigned char type8;
typedef unsigned short type16;
typedef unsigned long int type32;

/* Amiga version string */
char *amiverstag = "\0$VER: " PRGNAME " " PRGVERSION " (" PRGDATE ")";

#define MAXLENGTH 131072

int fdi1, fdi2, fdo1, fdo2;

static type8 interbuf[256];
static type8 databuf[256];
static type8 zerobuf[256];
type32 length;
type8 endfile_reached = FALSE;
type32 bytecount = 256;
type32 file_length;

void
ex (char *error)
{
  fprintf (stderr, PRGNAME ": %s\n", error);
  exit (1);
}

void
usage (void)
{
  fprintf (stderr,
	   PRGNAME " version " PRGVERSION " (released " PRGDATE "):\n");
  fprintf (stderr,
	   "Converts z-code datafile into D64 image(s)\n");
  fprintf (stderr,
	   "(c) 1996,97,2001 by Paul David Doherty <42@pdd.de>\n\n");
  fprintf (stderr,
	   "Usage: " PRGNAME " infile.dat outfile.d64 [outfile2.d64]\n");
  exit (1);
}

unsigned char bam[] = {
    0x12,0x01, // track/sector
    0x41, // DOS version
    0x00, // unused
    0x15,0xff,0xff,0x1f, // track 01 (21 sectors)
    0x15,0xff,0xff,0x1f, // track 02
    0x15,0xff,0xff,0x1f, // track 03
    0x00,0x00,0x00,0x00, // track 04 mark track 4-17 as occupied (contains story data)
    0x00,0x00,0x00,0x00, // track 05
    0x00,0x00,0x00,0x00, // track 06
    0x00,0x00,0x00,0x00, // track 07
    0x00,0x00,0x00,0x00, // track 08
    0x00,0x00,0x00,0x00, // track 09
    0x00,0x00,0x00,0x00, // track 10
    0x00,0x00,0x00,0x00, // track 11
    0x00,0x00,0x00,0x00, // track 12
    0x00,0x00,0x00,0x00, // track 13
    0x00,0x00,0x00,0x00, // track 14
    0x00,0x00,0x00,0x00, // track 15
    0x00,0x00,0x00,0x00, // track 16
    0x00,0x00,0x00,0x00, // track 17
    0x11,0xfc,0xff,0x07, // track 18 (19 sectors)
    0x13,0xff,0xff,0x07, // track 19
    0x13,0xff,0xff,0x07, // track 20
    0x13,0xff,0xff,0x07, // track 21
    0x13,0xff,0xff,0x07, // track 22
    0x13,0xff,0xff,0x07, // track 23
    0x13,0xff,0xff,0x07, // track 24
    0x12,0xff,0xff,0x03, // track 25 (18 sectors)
    0x12,0xff,0xff,0x03, // track 26
    0x12,0xff,0xff,0x03, // track 27
    0x12,0xff,0xff,0x03, // track 28
    0x12,0xff,0xff,0x03, // track 29
    0x12,0xff,0xff,0x03, // track 30
    0x11,0xff,0xff,0x01, // track 31 (17 sectors)
    0x11,0xff,0xff,0x01,0x11,0xff,0xff,0x01,0x11,0xff,0xff,0x01,0x11,0xff,0xff,0x01,
    0x44,0x45,0x4a,0x41,0x56,0x55,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,// label (DEJAVU)
    0xa0,0xa0,0x30,0x30,0xa0,0x32,0x41,0xa0,0xa0,0xa0,0xa0,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};

void
trans1801 ()
{
    write (fdo1, bam, 256);
}

void
trans1802 ()
{
    unsigned char data =0xff;
    write (fdo1, zerobuf, 1);
    write (fdo1, &data, 1);
    write (fdo1, zerobuf, 254);
}

void
transinter (type16 secs, int outfile)
{
  type16 i;
  if (outfile == 1)
    outfile = fdo1;
  else
    outfile = fdo2;

  for (i = 0; i < secs; i++)
    {
      read (fdi1, interbuf, 256);
      write (outfile, interbuf, 256);
    }
}

void
transzero (type16 secs)
{
  type16 i;
  for (i = 0; i < secs; i++)
    write (fdo1, zerobuf, 256);
}

void
trans256 (int outfile)
{
  type16 i;
  if (outfile == 1)
    outfile = fdo1;
  else
    outfile = fdo2;

  length = read (fdi2, databuf, 256);
  if (endfile_reached == TRUE)
    length = 0;
  else if ((bytecount + length) >= file_length)
    {
      length = file_length - bytecount;
      endfile_reached = TRUE;
    }

  for (i = length; i < 256; i++)
    databuf[i] = 0;
  write (outfile, databuf, 256);
  bytecount = bytecount + 256;
}

void
transdata (type16 secs, int outfile)
{
  type16 i;
  for (i = 0; i < secs; i++)
    trans256 (outfile);
}

int
main (int argc, char **argv)
{
  type16 i, j;
  type16 ckdsum = 0;
  type8 version;

#ifdef __TURBOC__
  _fmode = O_BINARY;
#endif

  if (argc == 1)
    usage ();
  else if ((argc == 2) || (argc > 4))
    ex ("needs 2 or 3 filenames");

  if ((fdi1 = open ("inftod64.dat", O_LEGGERE, 0)) == -1)
    ex ("could not find \"inftod64.dat\"");

  for (i = 0; i < 147; i++)
    {
      if ((length = read (fdi1, interbuf, 256)) != 256)
	ex ("\"inftod64.dat\" too short");
      for (j = 0; j < 256; j++)
	ckdsum = ckdsum + interbuf[j];
    }
  if (ckdsum != 20987)
    ex ("\"inftod64.dat\" is corrupted");
  close (fdi1);
  fdi1 = open ("inftod64.dat", O_LEGGERE, 0);

  if ((fdi2 = open (argv[1], O_LEGGERE, 0)) == -1)
    ex ("could not open input file");
  if ((fdo1 = open (argv[2], O_SCRIVERE | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)) == -1)
    ex ("could not create output file");

  for (j = 0; j < 256; j++)
    zerobuf[j] = 0;

  if ((length = read (fdi2, databuf, 256)) != 256)
    ex ("input file much too short");
  version = databuf[0];
  if (version == 5)
    for (i = 0; i < 37; i++)
      read (fdi1, interbuf, 256);
  else if (version != 3)
    ex ("unsupported Z-code version");

  file_length = ((256L * (type32) databuf[0x1a]) +
		 (type32) databuf[0x1b]) * 2L;
  if (file_length == 0L)
    file_length = MAXLENGTH;
  if ((version == 4) || (version == 5))
    file_length = file_length * 2L;

  if (version == 3)
    {
      transzero (1);
      transinter (16, 1);	/* track 1 */
      transzero (4);
      transinter (16, 1);	/* track 2 */
      transzero (47);
      write (fdo1, databuf, 256);	/* track 5 */
      transdata (16, 1);
      transzero (4);
      for (i = 6; i < 17; i++)
	{
	  transdata (17, 1);
	  transzero (4);
	}
      transinter (1, 1);	/* track 17 */
      transzero (9);
      transinter (1, 1);
      transzero (9);
      transinter (1, 1);
#ifdef NEWBAM
      trans1801();
      trans1802();
#else
      transinter (2, 1);    /* track 18 */
#endif
      transdata (17, 1);
      for (i = 19; i < 36; i++)
	{
	  transdata (17, 1);
	  if (i <= 30)
	    transzero (1);
	  if (i <= 24)
	    transzero (1);
	}
    }
  else
    /* V5 */
    {
      transinter (53, 1);
      transzero (31);
      databuf[1] |= 4;
      if (databuf[4] > 0x2b)
	{
	  printf ("Resident data size reduced from %02x%02x to 2bc0\n",
		  databuf[4], databuf[5]);
	  databuf[4] = 0x2b;
	  databuf[5] = 0xc0;
	}
      if (databuf[4] == 0x2b)
	if (databuf[5] > 0xc0)
	  databuf[5] = 0xc0;

      write (fdo1, databuf, 256);	/* track 5 */
      transdata (174, 1);
      transzero (77);
      transinter (1, 1);	/* track 17 */
      transzero (9);
      transinter (1, 1);
      transzero (9);
      transinter (3, 1);
      transzero (36);
      transinter (50, 1);
      transzero (238);
    }

  if ((version == 3) && (read (fdi2, databuf, 256) != 0))
    ex ("V3 datafile longer than 130560 bytes, create failed");

  if ((version == 5) && (read (fdi2, databuf, 256) != 0))
    if (argc == 3)
      ex ("need second output file");
    else
      {
	if ((fdo2 = open (argv[3], O_SCRIVERE | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)) == -1)
	  ex ("could not create second output file");

	write (fdo2, databuf, 256);	/* track 1 */
	transdata (356, 2);
	transinter (1, 2);
	transdata (37, 2);
	transinter (1, 2);
	transdata (287, 2);
	close (fdo2);

	if (read (fdi2, databuf, 256) != 0)
	  ex ("V5 datafile longer than 219136 bytes, create failed");
      }

  printf ("Done\n");
  close (fdi1);
  close (fdi2);
  close (fdo1);
  return 0;
}
