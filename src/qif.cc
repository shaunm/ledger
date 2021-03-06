/*
 * Copyright (c) 2003-2008, John Wiegley.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 *
 * - Neither the name of New Artisans LLC nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "journal.h"
#include "qif.h"
#include "utils.h"

namespace ledger {

#define MAX_LINE 1024

static char         line[MAX_LINE + 1];
static path         pathname;
static unsigned int src_idx;
static unsigned int linenum;

static inline char * get_line(std::istream& in) {
  in.getline(line, MAX_LINE);
  int len = std::strlen(line);
  if (line[len - 1] == '\r')
    line[len - 1] = '\0';
  linenum++;
  return line;
}

bool qif_parser_t::test(std::istream& in) const
{
  char magic[sizeof(unsigned int) + 1];
  in.read(magic, sizeof(unsigned int));
  magic[sizeof(unsigned int)] = '\0';
  in.clear();
  in.seekg(0, std::ios::beg);

  return (std::strcmp(magic, "!Typ") == 0 ||
	  std::strcmp(magic, "\n!Ty") == 0 ||
	  std::strcmp(magic, "\r\n!T") == 0);
}

unsigned int qif_parser_t::parse(std::istream& in,
				 session_t&    session,
				 journal_t&    journal,
				 account_t *   master,
				 const path *  original_file)
{
  std::auto_ptr<entry_t>  entry;
  std::auto_ptr<amount_t> amount;

  xact_t *	xact;
  unsigned int  count	      = 0;
  account_t *   misc	      = NULL;
  commodity_t * def_commodity = NULL;
  bool          saw_splits    = false;
  bool          saw_category  = false;
  xact_t *	total         = NULL;

  entry.reset(new entry_t);
  xact = new xact_t(master);
  entry->add_xact(xact);

  pathname = journal.sources.back();
  src_idx  = journal.sources.size() - 1;
  linenum  = 1;

  istream_pos_type beg_pos  = 0;
  unsigned long    beg_line = 0;

#define SET_BEG_POS_AND_LINE()			\
  if (! beg_line) {				\
    beg_pos  = in.tellg();			\
    beg_line = linenum;				\
  }

  while (in.good() && ! in.eof()) {
    char c;
    in.get(c);
    switch (c) {
    case ' ':
    case '\t':
      if (peek_next_nonws(in) != '\n') {
	get_line(in);
	throw parse_error("Line begins with whitespace");
      }
      // fall through...

    case '\n':
      linenum++;
    case '\r':                  // skip blank lines
      break;

    case '!':
      get_line(in);

      if (std::strcmp(line, "Type:Invst") == 0 ||
	  std::strcmp(line, "Account") == 0 ||
	  std::strcmp(line, "Type:Cat") == 0 ||
	  std::strcmp(line, "Type:Class") == 0 ||
	  std::strcmp(line, "Type:Memorized") == 0)
	throw_(parse_error, "QIF files of type " << line << " are not supported.");
      break;

    case 'D':
      SET_BEG_POS_AND_LINE();
      get_line(in);
      // jww (2008-08-01): Is this just a date?
      entry->_date = parse_date(line);
      break;

    case 'T':
    case '$': {
      SET_BEG_POS_AND_LINE();
      get_line(in);
      xact->amount.parse(line);

      unsigned char flags = xact->amount.commodity().flags();
      unsigned char prec  = xact->amount.commodity().precision();

      if (! def_commodity) {
	def_commodity = amount_t::current_pool->find_or_create("$");
	assert(def_commodity);
      }
      xact->amount.set_commodity(*def_commodity);

      def_commodity->add_flags(flags);
      if (prec > def_commodity->precision())
	def_commodity->set_precision(prec);

      if (c == '$') {
	saw_splits = true;
	xact->amount.negate();
      } else {
	total = xact;
      }
      break;
    }

    case 'C':
      SET_BEG_POS_AND_LINE();
      c = in.peek();
      if (c == '*' || c == 'X') {
	in.get(c);
	xact->set_state(item_t::CLEARED);
      }
      break;

    case 'N':
      SET_BEG_POS_AND_LINE();
      get_line(in);
      entry->code = line;
      break;

    case 'P':
    case 'M':
    case 'L':
    case 'S':
    case 'E': {
      SET_BEG_POS_AND_LINE();
      get_line(in);

      switch (c) {
      case 'P':
	entry->payee = line;
	break;

      case 'S':
	xact = new xact_t(NULL);
	entry->add_xact(xact);
	// fall through...
      case 'L': {
	int len = std::strlen(line);
	if (line[len - 1] == ']')
	  line[len - 1] = '\0';
	xact->account = journal.find_account(line[0] == '[' ?
					      line + 1 : line);
	if (c == 'L')
	  saw_category = true;
	break;
      }

      case 'M':
      case 'E':
	xact->note = line;
	break;
      }
      break;
    }

    case 'A':
      SET_BEG_POS_AND_LINE();
      // jww (2004-08-19): these are ignored right now
      get_line(in);
      break;

    case '^': {
      account_t * other;
      if (xact->account == master) {
	if (! misc)
	  misc = journal.find_account("Miscellaneous");
	other = misc;
      } else {
	other = master;
      }

      if (total && saw_category) {
	if (! saw_splits)
	  total->amount.negate(); // negate, to show correct flow
	else
	  total->account = other;
      }

      if (! saw_splits) {
	xact_t * nxact = new xact_t(other);
	// The amount doesn't need to be set because the code below
	// will balance this xact against the other.
	entry->add_xact(nxact);
      }

      if (journal.add_entry(entry.get())) {
	entry->src_idx  = src_idx;
	entry->beg_pos  = beg_pos;
	entry->beg_line = beg_line;
	entry->end_pos  = in.tellg();
	entry->end_line = linenum;
	entry.release();
	count++;
      }

      // reset things for the next entry
      entry.reset(new entry_t);
      xact = new xact_t(master);
      entry->add_xact(xact);

      saw_splits   = false;
      saw_category = false;
      total        = NULL;
      beg_line	   = 0;
      break;
    }

    default:
      get_line(in);
      break;
    }
  }

  return count;
}

} // namespace ledger
