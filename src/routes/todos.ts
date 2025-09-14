import { Request, Response, Router } from 'express';
import { todoStore } from '../store/todoStore';
import { CreateTodoRequest, UpdateTodoRequest } from '../types/todo';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  const todos = todoStore.getAll();
  res.json(todos);
});

router.get('/:id', (req: Request, res: Response) => {
  const { id } = req.params;
  const todo = todoStore.getById(id);
  
  if (!todo) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  
  res.json(todo);
});

router.post('/', (req: Request, res: Response) => {
  const { title, description }: CreateTodoRequest = req.body;
  
  if (!title || title.trim() === '') {
    return res.status(400).json({ error: 'Title is required' });
  }
  
  const todo = todoStore.create({ title: title.trim(), description });
  res.status(201).json(todo);
});

router.put('/:id', (req: Request, res: Response) => {
  const { id } = req.params;
  const updates: UpdateTodoRequest = req.body;
  
  if (updates.title !== undefined && updates.title.trim() === '') {
    return res.status(400).json({ error: 'Title cannot be empty' });
  }
  
  const updatedTodo = todoStore.update(id, updates);
  
  if (!updatedTodo) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  
  res.json(updatedTodo);
});

router.delete('/:id', (req: Request, res: Response) => {
  const { id } = req.params;
  const deleted = todoStore.delete(id);
  
  if (!deleted) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  
  res.status(204).send();
});

export { router as todoRoutes };