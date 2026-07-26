<template>
  <div class="elder-app">
    <header class="brand-bar" aria-label="安信伴老">
      <span class="brand-mark" aria-hidden="true">安</span>
      <span class="brand-name">安信伴老</span>
      <span class="app-label">老人端</span>
    </header>

    <main class="home" aria-labelledby="home-title">
      <section class="welcome-panel">
        <p class="eyebrow">先看清，再决定</p>
        <h1 id="home-title">反诈练习，慢慢来</h1>
        <p class="welcome-copy">
          在安全的情景里练习识别骗局。这里不会催促您，也不会替您联系任何人。
        </p>
        <a class="primary-action" href="#practice-guide">
          <span>看看怎么练</span>
          <span aria-hidden="true">↓</span>
        </a>
      </section>

      <section id="practice-guide" class="practice-guide" aria-labelledby="guide-title">
        <div class="guide-heading">
          <p class="eyebrow">一次练习的路线</p>
          <h2 id="guide-title">三步，心里更有底</h2>
        </div>

        <ol class="practice-route">
          <li>
            <span class="step-marker" aria-hidden="true">1</span>
            <div>
              <strong>看情景</strong>
              <p>先听清对方说了什么。</p>
            </div>
          </li>
          <li>
            <span class="step-marker" aria-hidden="true">2</span>
            <div>
              <strong>做选择</strong>
              <p>按自己的判断慢慢选。</p>
            </div>
          </li>
          <li>
            <span class="step-marker" aria-hidden="true">3</span>
            <div>
              <strong>学一招</strong>
              <p>看懂风险，下次更安心。</p>
            </div>
          </li>
        </ol>

        <p class="ready-note" role="status">
          <span class="ready-dot" aria-hidden="true"></span>
          老人端已经准备好
        </p>
      </section>
    </main>

    <footer class="home-footer">遇到拿不准的事，先停一下，再找可信的人商量。</footer>
  </div>
</template>
