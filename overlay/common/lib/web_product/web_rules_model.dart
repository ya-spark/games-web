// The model of one game's how-to-play text (rules and tips). The text itself is in web_rules_data.dart, which
// scripts/sync_rules.py generates from the apps' own catalogues.
class GameRules {
  const GameRules(this.title, this.rules, this.tips);
  final String title;
  final List<String> rules;
  final List<String> tips;
}
