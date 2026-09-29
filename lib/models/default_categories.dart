/// Starter categories created with a new database. `key` identifies each one
/// so the name can be supplied in the user's language at first launch; after
/// that the names are ordinary user data.
const defaultCategories = <({String key, String name, String type, String color, String icon})>[
  (key: 'groceries', name: 'Groceries', type: 'expense', color: '#22c55e', icon: 'cart'),
  (key: 'dining', name: 'Dining Out', type: 'expense', color: '#f97316', icon: 'utensils'),
  (key: 'transport', name: 'Transport', type: 'expense', color: '#0ea5e9', icon: 'car'),
  (key: 'housing', name: 'Housing', type: 'expense', color: '#a855f7', icon: 'home'),
  (key: 'utilities', name: 'Utilities', type: 'expense', color: '#eab308', icon: 'bolt'),
  (key: 'entertainment', name: 'Entertainment', type: 'expense', color: '#ec4899', icon: 'film'),
  (key: 'shopping', name: 'Shopping', type: 'expense', color: '#ef4444', icon: 'bag'),
  (key: 'health', name: 'Health', type: 'expense', color: '#14b8a6', icon: 'heart'),
  (key: 'subscriptions', name: 'Subscriptions', type: 'expense', color: '#f59e0b', icon: 'tag'),
  (key: 'otherExpense', name: 'Other Expense', type: 'expense', color: '#64748b', icon: 'tag'),
  (key: 'salary', name: 'Salary', type: 'income', color: '#16a34a', icon: 'banknote'),
  (key: 'freelance', name: 'Freelance', type: 'income', color: '#0d9488', icon: 'briefcase'),
  (key: 'otherIncome', name: 'Other Income', type: 'income', color: '#475569', icon: 'plus-circle'),
];
