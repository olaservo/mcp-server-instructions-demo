import { Todo, CreateTodoRequest, UpdateTodoRequest } from '../types/todo';

class TodoStore {
  private todos: Map<string, Todo> = new Map();
  private nextId = 1;

  private generateId(): string {
    return (this.nextId++).toString();
  }

  getAll(): Todo[] {
    return Array.from(this.todos.values());
  }

  getById(id: string): Todo | undefined {
    return this.todos.get(id);
  }

  create(todoData: CreateTodoRequest): Todo {
    const now = new Date();
    const todo: Todo = {
      id: this.generateId(),
      title: todoData.title,
      description: todoData.description,
      completed: false,
      createdAt: now,
      updatedAt: now,
    };

    this.todos.set(todo.id, todo);
    return todo;
  }

  update(id: string, updates: UpdateTodoRequest): Todo | null {
    const todo = this.todos.get(id);
    if (!todo) {
      return null;
    }

    const updatedTodo: Todo = {
      ...todo,
      ...updates,
      updatedAt: new Date(),
    };

    this.todos.set(id, updatedTodo);
    return updatedTodo;
  }

  delete(id: string): boolean {
    return this.todos.delete(id);
  }
}

export const todoStore = new TodoStore();