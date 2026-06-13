import 'package:flutter/material.dart';

class CitationText extends StatelessWidget {
  final String text;
  final Function(int pageNumber) onCitationTapped;

  const CitationText({
    super.key,
    required this.text,
    required this.onCitationTapped,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    
    // Regex to match [Page X] where X is a number
    final regex = RegExp(r'\[Page\s+(\d+)\]', caseSensitive: false);
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final spans = <InlineSpan>[];
    int currentPosition = 0;

    for (final match in matches) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, match.start),
          style: defaultStyle,
        ));
      }

      final pageStr = match.group(1);
      if (pageStr != null) {
        final pageNum = int.tryParse(pageStr) ?? 1;

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ActionChip(
              label: Text('Page $pageNum'),
              labelStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => onCitationTapped(pageNum),
            ),
          ),
        ));
      }

      currentPosition = match.end;
    }

    if (currentPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPosition),
        style: defaultStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
