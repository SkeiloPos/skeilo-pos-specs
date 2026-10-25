// Spec 134: traductor simulado para verificar sin un traductor real (que no se puede
// disparar desde automatización). Pegar en la consola de DevTools de la pestaña a probar.
//
//   __sim.translate()                       -> como Chrome: <font><font> + clase y lang en <html>
//   __sim.translate({ markers: false })     -> solo <font>, sin clase ni lang
//   __sim.translate({ markers: false, tag: 'span' })
//                                           -> sin ninguna marca conocida: solo el canario estructural
//   __sim.revert()                          -> restaura los nodos originales (traducción "revertida")
//
// Reproduce el mecanismo medido en la spec: el nodo de texto original queda
// desconectado de la página y se reemplaza por una copia; Angular sigue
// escribiendo en el original, así que la pantalla queda desfasada sin errores.
(() => {
  const swaps = [];
  const wrapAll = (tag) => {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    for (const node of nodes) {
      const parent = node.parentNode;
      if (!node.nodeValue.trim() || !parent || parent.closest('script,style,noscript')) continue;
      const outer = document.createElement(tag);
      const inner = document.createElement(tag);
      outer.style.verticalAlign = inner.style.verticalAlign = 'inherit';
      inner.textContent = node.nodeValue;
      outer.appendChild(inner);
      parent.replaceChild(outer, node);
      swaps.push([outer, node]);
    }
  };
  window.__sim = {
    translate({ markers = true, tag = 'font' } = {}) {
      wrapAll(tag);
      if (markers) {
        document.documentElement.classList.add('translated-ltr');
        document.documentElement.lang = 'en';
      }
    },
    revert() {
      for (const [wrapper, original] of swaps.reverse()) wrapper.parentNode?.replaceChild(original, wrapper);
      swaps.length = 0;
      document.documentElement.classList.remove('translated-ltr');
      document.documentElement.lang = 'es';
    },
  };
})();
