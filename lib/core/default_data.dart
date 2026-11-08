import 'util.dart';

/// Starting data for a brand-new account (same categories as the web app).
/// The web app fills in any other fields it needs the next time it opens.
Map<String, dynamic> newUserData(String name) {
  const exp = [
    ['Rent', '🏠'], ['Electricity', '⚡'], ['Water', '🚰'], ['Gas', '🔥'], ['Garbage', '🗑️'], ['Groceries', '🛒'],
    ['Phone', '☎️'], ['Internet', '📶'], ['TV', '📺'], ['Domestic Help', '🧹'], ['Transport', '🚕'], ['Fuel', '⛽'],
    ['Vehicle', '🚗'], ['Parking', '🅿️'], ['Tuition', '📖'], ['Books', '📚'], ['Activities', '🎨'], ['Doctor', '🩺'],
    ['Meds', '💊'], ['Insurance', '🛡️'], ['Dental', '🦷'], ['Clothing', '👕'], ['Salon', '💇'], ['Gym', '🏋️'],
    ['Dining', '🍕'], ['Entertainment', '🎭'], ['Travel', '✈️'], ['Gifts', '🎁'], ['Education', '🎓'], ['Shopping', '🛍️'],
    ['Kids', '🧸'], ['Pets', '🐾'], ['Charity', '🤲'], ['Bank Charges', '🏦'], ['Other', '📦'],
  ];
  const inc = [
    ['Salary', '💵'], ['Freelance Income', '💻'], ['Business Income', '🏢'], ['Investment Returns', '📈'], ['Bonus', '🎉'],
    ['Rental Income', '🏘️'], ['Interest', '🪙'], ['Gifts Received', '🎁'], ['Refunds', '↩️'], ['Other Income', '💰'],
  ];
  final cats = <Map<String, dynamic>>[];
  for (var i = 0; i < exp.length; i++) {
    cats.add({'id': 'ce$i', 'name': exp[i][0], 'icon': exp[i][1], 'kind': 'expense', 'parent': null});
  }
  for (var i = 0; i < inc.length; i++) {
    cats.add({'id': 'ci$i', 'name': inc[i][0], 'icon': inc[i][1], 'kind': 'income', 'parent': null});
  }
  return {
    'v': 2,
    'accounts': [
      {'id': uid(), 'name': 'Cash', 'currency': 'LKR', 'type': 'wallet', 'include': true, 'isDefault': true}
    ],
    'categories': cats,
    'txns': [],
    'rates': [],
    'settings': {'name': name, 'base': 'LKR', 'theme': 'system', 'lang': 'en'},
  };
}
