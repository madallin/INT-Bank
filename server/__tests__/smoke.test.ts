describe('Server smoke test', () => {
  it('should pass basic sanity check', () => {
    expect(1 + 1).toBe(2);
  });

  it('should have required dependencies installed', () => {
    const pkg = require('../package.json');
    expect(pkg.dependencies).toBeDefined();
    expect(pkg.dependencies.express).toBeDefined();
    expect(pkg.dependencies.typeorm).toBeDefined();
  });

  it('should have test dependencies installed', () => {
    const pkg = require('../package.json');
    expect(pkg.devDependencies).toBeDefined();
    expect(pkg.devDependencies.jest).toBeDefined();
    expect(pkg.devDependencies['ts-jest']).toBeDefined();
  });
});
