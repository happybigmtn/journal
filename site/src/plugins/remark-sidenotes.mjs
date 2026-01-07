/**
 * Remark plugin to transform footnotes into Tufte-style sidenotes
 *
 * Transforms:
 *   Text with a footnote[^1].
 *   [^1]: The footnote content.
 *
 * Into HTML structure that allows CSS to position notes in margins:
 *   <span class="sidenote-wrapper">
 *     Text with a footnote<label for="sn-1" class="sidenote-toggle">1</label>
 *     <input type="checkbox" id="sn-1" class="sidenote-checkbox" />
 *     <span class="sidenote">
 *       <span class="sidenote-number">1</span>
 *       The footnote content.
 *     </span>
 *   </span>
 */

import { visit } from 'unist-util-visit';

export default function remarkSidenotes() {
  return (tree) => {
    // Collect all footnote definitions first
    const footnoteDefinitions = new Map();

    visit(tree, 'footnoteDefinition', (node) => {
      // Store the footnote content
      footnoteDefinitions.set(node.identifier, {
        identifier: node.identifier,
        children: node.children
      });
    });

    // Counter for sidenote IDs
    let sidenoteCount = 0;

    // Transform footnote references into sidenotes
    visit(tree, 'footnoteReference', (node, index, parent) => {
      if (!parent || index === undefined) return;

      const definition = footnoteDefinitions.get(node.identifier);
      if (!definition) return;

      sidenoteCount++;
      const sidenoteId = `sn-${sidenoteCount}`;

      // Create the sidenote structure as HTML
      const sidenoteHtml = {
        type: 'html',
        value: `<label for="${sidenoteId}" class="sidenote-toggle sidenote-number">${sidenoteCount}</label><input type="checkbox" id="${sidenoteId}" class="sidenote-checkbox" /><span class="sidenote"><span class="sidenote-number">${sidenoteCount}</span> `
      };

      const sidenoteEnd = {
        type: 'html',
        value: '</span>'
      };

      // Get footnote content as plain text (simplified)
      const footnoteText = getPlainText(definition.children);

      // Insert sidenote structure after the reference
      parent.children.splice(index, 1,
        sidenoteHtml,
        { type: 'text', value: footnoteText },
        sidenoteEnd
      );

      return index + 3; // Skip past the inserted nodes
    });

    // Remove footnote definitions from the tree (they're now inline)
    visit(tree, 'footnoteDefinition', (node, index, parent) => {
      if (parent && index !== undefined) {
        parent.children.splice(index, 1);
        return index; // Re-process at same index
      }
    });
  };
}

/**
 * Extract plain text from MDAST nodes
 */
function getPlainText(nodes) {
  let text = '';

  function extract(node) {
    if (node.type === 'text') {
      text += node.value;
    } else if (node.type === 'inlineCode') {
      text += node.value;
    } else if (node.children) {
      node.children.forEach(extract);
    }
  }

  nodes.forEach(extract);
  return text.trim();
}
