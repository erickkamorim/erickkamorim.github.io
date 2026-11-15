/* =========================================================
   Portfólio — Erick Amorim
   JavaScript puro (sem bibliotecas). Funções do site:
   1. Tema claro/escuro (salvo no navegador)
   2. Animação de entrada e contadores dos números
   3. Menu que destaca a seção visível (topo e celular)
   4. Galeria de prints dos projetos
   5. Validação e simulação de envio do formulário de contato
   ========================================================= */

(function () {
  'use strict';

  /* ---------------------------------------------------------
     1. TEMA CLARO / ESCURO
     O tema fica no atributo data-tema da tag <html>.
     O CSS usa [data-tema="claro"] para trocar as cores.
     --------------------------------------------------------- */
  var raiz = document.documentElement;
  var botaoTema = document.getElementById('botao-tema');

  // Lê o tema salvo. O try/catch evita erro em navegadores que bloqueiam o localStorage.
  function lerTemaSalvo() {
    try { return localStorage.getItem('tema'); } catch (e) { return null; }
  }

  function aplicarTema(tema) {
    if (tema === 'claro') {
      raiz.setAttribute('data-tema', 'claro');
    } else {
      raiz.removeAttribute('data-tema'); // sem atributo = tema escuro (padrão)
    }
    // Atualiza o texto lido por leitores de tela
    botaoTema.setAttribute('aria-label', tema === 'claro' ? 'Mudar para o tema escuro' : 'Mudar para o tema claro');
    // Atualiza a cor da barra do navegador no celular
    document.querySelector('meta[name="theme-color"]').setAttribute('content', tema === 'claro' ? '#f6f5f0' : '#08090f');
  }

  aplicarTema(lerTemaSalvo() || 'escuro');

  botaoTema.addEventListener('click', function () {
    var novoTema = raiz.getAttribute('data-tema') === 'claro' ? 'escuro' : 'claro';
    aplicarTema(novoTema);
    try { localStorage.setItem('tema', novoTema); } catch (e) { /* se não der para salvar, só não lembra na próxima visita */ }
  });

  /* ---------------------------------------------------------
     2. ANIMAÇÃO DE ENTRADA E CONTADORES
     Elementos com a classe .rv aparecem suavemente quando entram na tela.
     Números com data-count sobem de 0 até o valor final.
     --------------------------------------------------------- */
  function animarContador(elemento) {
    var valorFinal = Number(elemento.getAttribute('data-count'));
    var inicio = null;
    var duracao = 1400; // milissegundos

    function passo(agora) {
      if (!inicio) inicio = agora;
      var progresso = Math.min((agora - inicio) / duracao, 1);
      var suavizado = 1 - Math.pow(1 - progresso, 3); // desacelera no final
      elemento.textContent = Math.round(valorFinal * suavizado).toLocaleString('pt-BR');
      if (progresso < 1) requestAnimationFrame(passo);
    }
    requestAnimationFrame(passo);
  }

  var elementosAnimados = document.querySelectorAll('.rv');

  if ('IntersectionObserver' in window) {
    var observador = new IntersectionObserver(function (entradas) {
      entradas.forEach(function (entrada) {
        if (entrada.isIntersecting) {
          entrada.target.classList.add('in');
          entrada.target.querySelectorAll('[data-count]').forEach(animarContador);
          observador.unobserve(entrada.target); // anima uma vez só
        }
      });
    }, { threshold: 0.15 });
    elementosAnimados.forEach(function (el) { observador.observe(el); });
  } else {
    // Navegador antigo: mostra tudo sem animação
    elementosAnimados.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---------------------------------------------------------
     3. MENU ATIVO CONFORME A ROLAGEM
     Os dois menus (topo e celular) têm os links na mesma ordem
     das seções abaixo. O link da seção visível ganha a classe "on".
     --------------------------------------------------------- */
  var cabecalho = document.getElementById('top');
  var secoes = ['sobre', 'formacao', 'portfolio', 'contato'];
  var menus = [document.querySelectorAll('.links a'), document.querySelectorAll('.mnav a')];

  function atualizarMenu() {
    // Fundo desfocado no cabeçalho depois que a página rola um pouco
    cabecalho.classList.toggle('sc', window.scrollY > 20);

    var linhaDeLeitura = window.scrollY + window.innerHeight * 0.35;
    var ativo = -1; // -1 = ainda no topo (nenhuma seção ativa)

    secoes.forEach(function (id, i) {
      var secao = document.getElementById(id);
      if (secao && secao.getBoundingClientRect().top + window.scrollY <= linhaDeLeitura) ativo = i;
    });

    // No fim da página, a última seção (Contato) fica ativa
    if (window.innerHeight + window.scrollY >= document.body.scrollHeight - 4) ativo = secoes.length - 1;

    menus.forEach(function (lista) {
      lista.forEach(function (link, i) { link.classList.toggle('on', i === ativo); });
    });
  }

  window.addEventListener('scroll', atualizarMenu, { passive: true });
  atualizarMenu();

  /* ---------------------------------------------------------
     4. GALERIA DE PRINTS (lightbox)
     Cada botão com data-gal="nome:posição" abre a galeria.
     Cada item: [imagem, título, descrição]
     --------------------------------------------------------- */
  var galerias = {
    anac: [
      ['assets/anac-dashboard.webp', 'Dashboard completo', 'Visão geral com KPIs, evolução anual, ASK × RPK e carga'],
      ['assets/anac-figma.webp', '1. Protótipo no Figma', 'Layout, paleta e navegação definidos antes do Power BI'],
      ['assets/anac-powerbi.webp', '2. Desenvolvimento no Power BI', 'Modelagem, medidas em DAX e visualizações'],
      ['assets/anac-filtros.webp', '3. Painel de filtros', 'Período, empresa, natureza do voo e país'],
      ['assets/anac-tooltip.webp', '4. Tooltip personalizado', 'Ano, passageiros, carga, load factor e empresas']
    ],
    nexus: [
      ['assets/nexus-visao.webp', 'Visão geral', 'Selic, IPCA, dólar, juro real e decisões do Copom com dados do Banco Central'],
      ['assets/nexus-previsoes.webp', 'Previsões', 'IPCA dos próximos 6 meses com faixas de 80% e 95% e comparação com o Focus'],
      ['assets/nexus-metodologia.webp', 'Metodologia', 'Como as previsões são feitas e avaliadas, sem vazamento de dados'],
      ['assets/nexus-mobile.webp', 'Versão celular', 'Layout responsivo com navegação flutuante']
    ]
  };

  var caixa = document.getElementById('lb');
  var imagem = document.getElementById('lb-img');
  var legenda = document.getElementById('lb-cap');
  var pontos = document.getElementById('lb-dots');
  var galeriaAtual = galerias.anac;
  var posicao = 0;

  function mostrarPrint(i) {
    posicao = (i + galeriaAtual.length) % galeriaAtual.length; // volta ao início depois do último
    var item = galeriaAtual[posicao];
    imagem.src = item[0];
    imagem.alt = item[1];
    legenda.innerHTML = item[1] + '<small>' + item[2] + '</small>';
    Array.prototype.forEach.call(pontos.children, function (p, k) { p.classList.toggle('on', k === posicao); });
  }

  function abrirGaleria(nome, i) {
    galeriaAtual = galerias[nome];
    pontos.innerHTML = '';
    galeriaAtual.forEach(function () { pontos.appendChild(document.createElement('i')); });
    mostrarPrint(i);
    caixa.classList.add('on');
    document.body.style.overflow = 'hidden'; // trava a rolagem do fundo
  }

  function fecharGaleria() {
    caixa.classList.remove('on');
    document.body.style.overflow = '';
  }

  document.querySelectorAll('[data-gal]').forEach(function (botao) {
    botao.addEventListener('click', function () {
      var partes = botao.getAttribute('data-gal').split(':');
      abrirGaleria(partes[0], Number(partes[1]));
    });
  });
  caixa.querySelector('.x').addEventListener('click', fecharGaleria);
  caixa.querySelector('.p').addEventListener('click', function () { mostrarPrint(posicao - 1); });
  caixa.querySelector('.n').addEventListener('click', function () { mostrarPrint(posicao + 1); });
  caixa.addEventListener('click', function (e) { if (e.target === caixa) fecharGaleria(); });

  /* ---------------------------------------------------------
     5. FORMULÁRIO DE CONTATO
     Valida nome, e-mail e mensagem antes do envio.
     O envio é simulado: nada sai do navegador. Depois da
     validação, os campos são limpos e aparece um modal de sucesso.
     --------------------------------------------------------- */
  var formulario = document.getElementById('form-contato');
  var botaoEnviar = document.getElementById('botao-enviar');
  var modal = document.getElementById('modal-sucesso');
  var botaoFecharModal = document.getElementById('fechar-modal');

  // Formato usuario@dominio.com: texto, @, texto, ponto, texto (sem espaços)
  var formatoEmail = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

  // Mostra ou limpa a mensagem de erro de um campo
  function marcarErro(campo, mensagem) {
    var caixaCampo = campo.closest('.campo');
    caixaCampo.classList.toggle('erro', mensagem !== '');
    caixaCampo.querySelector('.msg-erro').textContent = mensagem;
    campo.setAttribute('aria-invalid', mensagem !== '' ? 'true' : 'false');
  }

  // Regras de cada campo. Retorna a mensagem de erro ou '' se estiver certo.
  function validarCampo(campo) {
    var valor = campo.value.trim();

    if (campo.name === 'nome') {
      if (valor === '') return 'Informe seu nome.';
      if (valor.length < 3) return 'O nome precisa ter pelo menos 3 letras.';
    }
    if (campo.name === 'email') {
      if (valor === '') return 'Informe seu e-mail.';
      if (!formatoEmail.test(valor)) return 'Digite um e-mail válido, como usuario@dominio.com.';
    }
    if (campo.name === 'mensagem') {
      if (valor === '') return 'Escreva sua mensagem.';
      if (valor.length < 10) return 'A mensagem precisa ter pelo menos 10 caracteres.';
    }
    return '';
  }

  var campos = formulario.querySelectorAll('input, textarea');

  // Depois que o usuário sai de um campo, valida só aquele campo
  campos.forEach(function (campo) {
    campo.addEventListener('blur', function () { marcarErro(campo, validarCampo(campo)); });
    // Se o campo já estava com erro, some o aviso assim que a pessoa corrige
    campo.addEventListener('input', function () {
      if (campo.closest('.campo').classList.contains('erro')) marcarErro(campo, validarCampo(campo));
    });
  });

  formulario.addEventListener('submit', function (evento) {
    evento.preventDefault(); // impede o navegador de recarregar a página

    var primeiroComErro = null;
    campos.forEach(function (campo) {
      var erro = validarCampo(campo);
      marcarErro(campo, erro);
      if (erro && !primeiroComErro) primeiroComErro = campo;
    });

    // Se algum campo está errado, leva o cursor até ele e não envia
    if (primeiroComErro) {
      primeiroComErro.focus();
      return;
    }

    // Simulação do envio: mostra "Enviando..." por 1 segundo
    botaoEnviar.disabled = true;
    botaoEnviar.querySelector('span').textContent = 'Enviando...';

    setTimeout(function () {
      var nome = formulario.nome.value.trim().split(' ')[0];
      document.getElementById('modal-texto').textContent =
        'Obrigado, ' + nome + '! Vou ler sua mensagem e responder pelo e-mail informado.';

      formulario.reset(); // limpa os campos
      botaoEnviar.disabled = false;
      botaoEnviar.querySelector('span').textContent = 'Enviar mensagem';
      abrirModal();
    }, 1000);
  });

  function abrirModal() {
    modal.classList.add('on');
    botaoFecharModal.focus();
  }
  function fecharModal() {
    modal.classList.remove('on');
  }
  botaoFecharModal.addEventListener('click', fecharModal);
  modal.addEventListener('click', function (e) { if (e.target === modal) fecharModal(); });

  /* Teclado: Esc fecha a galeria ou o modal; setas trocam os prints */
  document.addEventListener('keydown', function (e) {
    if (modal.classList.contains('on') && e.key === 'Escape') fecharModal();
    if (!caixa.classList.contains('on')) return;
    if (e.key === 'Escape') fecharGaleria();
    if (e.key === 'ArrowLeft') mostrarPrint(posicao - 1);
    if (e.key === 'ArrowRight') mostrarPrint(posicao + 1);
  });
})();
