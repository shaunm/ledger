#include "emacs.h"

namespace ledger {

void format_emacs_transactions::write_entry(entry_t& entry)
{
  out << (((unsigned long)entry.beg_pos) + 1) << " ";

  out << (entry.state == entry_t::CLEARED ? "t" : "nil") << " ";

  out << "(" << (entry.date / 65536) << " "
      << (entry.date % 65536) << " 0) ";

  if (entry.code.empty())
    out << "nil ";
  else
    out << "\"" << entry.code << "\" ";

  if (entry.payee.empty())
    out << "nil";
  else
    out << "\"" << entry.payee << "\"";

  out << "\n";
}

void format_emacs_transactions::operator()(transaction_t& xact)
{
  if (! transaction_has_xdata(xact) ||
      ! (transaction_xdata_(xact).dflags & TRANSACTION_DISPLAYED)) {
    if (! last_entry) {
      out << "((";
      write_entry(*xact.entry);
    }
    else if (xact.entry != last_entry) {
      out << ")\n (";
      write_entry(*xact.entry);
    }
    else {
      out << "\n";
    }

    out << "  (\"" << xact.account->fullname() << "\" \""
	<< xact.amount << "\"";
    if (xact.cost)
      out << " \"" << *xact.cost << "\"";
    else if (! xact.note.empty())
      out << " nil";
    if (! xact.note.empty())
      out << " \"" << xact.note << "\"";
    out << ")";

    last_entry = xact.entry;

    transaction_xdata(xact).dflags |= TRANSACTION_DISPLAYED;
  }
}

} // namespace ledger

#ifdef USE_BOOST_PYTHON

#include <boost/python.hpp>

using namespace boost::python;
using namespace ledger;

void export_emacs()
{
  typedef
    pystream_handler_wrap<format_emacs_transactions, transaction_t>
    format_emacs_transactions_wrap;

  class_< format_emacs_transactions_wrap, bases<item_handler<transaction_t> > >
    ("FormatEmacsTransactions",
     init<PyObject *>()[with_custodian_and_ward<1, 2>()])
    .def("flush", &format_emacs_transactions_wrap::flush)
    .def("__call__", &format_emacs_transactions_wrap::operator())
    ;
}

#endif // USE_BOOST_PYTHON