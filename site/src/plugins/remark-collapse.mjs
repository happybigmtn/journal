/**
 * Remark plugin to transform :::collapse syntax into <details>/<summary> HTML
 *
 * Syntax:
 *   :::collapse Title goes here
 *   Content to be collapsed
 *   :::
 *
 * Options:
 *   :::collapse[open] Title - starts expanded
 */

import { visit } from 'unist-util-visit';

export default function remarkCollapse() {
  return (tree) => {
    const nodesToReplace = [];

    // Find paragraph nodes that start with :::collapse
    visit(tree, 'paragraph', (node, index, parent) => {
      if (!node.children || node.children.length === 0) return;

      const firstChild = node.children[0];
      if (firstChild.type !== 'text') return;

      const text = firstChild.value;
      const match = text.match(/^:::collapse(\[open\])?\s+(.*)/);

      if (match) {
        const isOpen = !!match[1];
        const title = match[2].trim();

        // Find the closing :::
        let endIndex = -1;
        for (let i = index + 1; i < parent.children.length; i++) {
          const sibling = parent.children[i];
          if (
            sibling.type === 'paragraph' &&
            sibling.children?.[0]?.type === 'text' &&
            sibling.children[0].value.trim() === ':::'
          ) {
            endIndex = i;
            break;
          }
        }

        if (endIndex !== -1) {
          // Collect content between start and end
          const contentNodes = parent.children.slice(index + 1, endIndex);

          nodesToReplace.push({
            parent,
            startIndex: index,
            endIndex,
            isOpen,
            title,
            contentNodes,
          });
        }
      }
    });

    // Replace nodes in reverse order to preserve indices
    for (let i = nodesToReplace.length - 1; i >= 0; i--) {
      const { parent, startIndex, endIndex, isOpen, title, contentNodes } =
        nodesToReplace[i];

      // Create the details/summary HTML structure
      const detailsNode = {
        type: 'html',
        value: `<details${isOpen ? ' open' : ''}>\n<summary>${escapeHtml(title)}</summary>\n`,
      };

      const closeDetailsNode = {
        type: 'html',
        value: '\n</details>',
      };

      // Remove the opening, content, and closing nodes
      const removed = parent.children.splice(
        startIndex,
        endIndex - startIndex + 1
      );

      // Insert new structure: opening details, content, closing details
      parent.children.splice(
        startIndex,
        0,
        detailsNode,
        ...contentNodes,
        closeDetailsNode
      );
    }
  };
}

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
