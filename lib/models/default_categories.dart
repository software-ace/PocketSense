/// Starter categories created with a new database. `key` identifies each one
/// so the name can be supplied in the user's language at first launch; after
/// that the names are ordinary user data.
const defaultCategories = <({String key, String name, String type, String color})>[
  (key: 'groceries', name: 'Groceries', type: 'expense', color: '#22c55e'),
  (key: 'dining', name: 'Dining Out', type: 'expense', color: '#f97316'),
  (key: 'transport', name: 'Transport', type: 'expense', color: '#0ea5e9'),
  (key: 'housing', name: 'Housing', type: 'expense', color: '#a855f7'),
  (key: 'utilities', name: 'Utilities', type: 'expense', color: '#eab308'),
  (key: 'entertainment', name: 'Entertainment', type: 'expense', color: '#ec4899'),
  (key: 'shopping', name: 'Shopping', type: 'expense', color: '#ef4444'),
  (key: 'health', name: 'Health', type: 'expense', color: '#14b8a6'),
  (key: 'subscriptions', name: 'Subscriptions', type: 'expense', color: '#f59e0b'),
  (key: 'otherExpense', name: 'Other Expense', type: 'expense', color: '#64748b'),
  (key: 'salary', name: 'Salary', type: 'income', color: '#16a34a'),
  (key: 'freelance', name: 'Freelance', type: 'income', color: '#0d9488'),
  (key: 'otherIncome', name: 'Other Income', type: 'income', color: '#475569'),
];
