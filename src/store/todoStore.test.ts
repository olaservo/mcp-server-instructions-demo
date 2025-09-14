import { todoStore } from './todoStore';

describe('TodoStore', () => {
  beforeEach(() => {
    // Clear the store before each test
    const todos = todoStore.getAll();
    todos.forEach(todo => todoStore.delete(todo.id));
  });

  describe('create', () => {
    it('should create a new todo', () => {
      const todoData = { title: 'Test Todo', description: 'Test description' };
      const todo = todoStore.create(todoData);

      expect(todo.id).toBeDefined();
      expect(todo.title).toBe('Test Todo');
      expect(todo.description).toBe('Test description');
      expect(todo.completed).toBe(false);
      expect(todo.createdAt).toBeInstanceOf(Date);
      expect(todo.updatedAt).toBeInstanceOf(Date);
    });
  });

  describe('getAll', () => {
    it('should return all todos', () => {
      todoStore.create({ title: 'Todo 1' });
      todoStore.create({ title: 'Todo 2' });

      const todos = todoStore.getAll();
      expect(todos).toHaveLength(2);
    });
  });

  describe('getById', () => {
    it('should return todo by id', () => {
      const created = todoStore.create({ title: 'Test Todo' });
      const found = todoStore.getById(created.id);

      expect(found).toEqual(created);
    });

    it('should return undefined for non-existent id', () => {
      const found = todoStore.getById('non-existent');
      expect(found).toBeUndefined();
    });
  });

  describe('update', () => {
    it('should update existing todo', () => {
      const created = todoStore.create({ title: 'Original Title' });
      const updated = todoStore.update(created.id, { title: 'Updated Title', completed: true });

      expect(updated?.title).toBe('Updated Title');
      expect(updated?.completed).toBe(true);
      expect(updated?.updatedAt.getTime()).toBeGreaterThanOrEqual(created.updatedAt.getTime());
    });

    it('should return null for non-existent id', () => {
      const result = todoStore.update('non-existent', { title: 'Updated' });
      expect(result).toBeNull();
    });
  });

  describe('delete', () => {
    it('should delete existing todo', () => {
      const created = todoStore.create({ title: 'To Delete' });
      const deleted = todoStore.delete(created.id);

      expect(deleted).toBe(true);
      expect(todoStore.getById(created.id)).toBeUndefined();
    });

    it('should return false for non-existent id', () => {
      const deleted = todoStore.delete('non-existent');
      expect(deleted).toBe(false);
    });
  });
});