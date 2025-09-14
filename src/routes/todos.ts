import { Request, Response, Router } from 'express';
import { todoStore } from '../store/todoStore';
import { CreateTodoRequest, UpdateTodoRequest } from '../types/todo';
import { validateTodoCreate, validateTodoUpdate, validateTodoId } from '../middleware/validation';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  const todos = todoStore.getAll();
  res.json(todos);
});

router.get('/:id', validateTodoId, (req: Request, res: Response) => {
  const { id } = req.params;
  const todo = todoStore.getById(id);
  
  if (!todo) {
    return res.status(404).json({ 
      error: 'Todo not found',
      details: [{ field: 'id', message: `Todo with ID ${id} does not exist`, value: id }]
    });
  }
  
  res.json(todo);
});

router.post('/', validateTodoCreate, (req: Request, res: Response) => {
  const { title, description }: CreateTodoRequest = req.body;
  
  // BUG: No try-catch block - if todoStore.create throws, server will crash
  const todo = todoStore.create({ 
    title: title.trim(), 
    description: description?.trim() || undefined 
  });
  res.status(201).json(todo);
});

router.put('/:id', validateTodoId, validateTodoUpdate, (req: Request, res: Response) => {
  const { id } = req.params;
  const updates: UpdateTodoRequest = req.body;
  
  // Trim string values
  if (updates.title) {
    updates.title = updates.title.trim();
  }
  if (updates.description) {
    updates.description = updates.description.trim();
  }
  
  const updatedTodo = todoStore.update(id, updates);
  
  if (!updatedTodo) {
    return res.status(404).json({ 
      error: 'Todo not found',
      details: [{ field: 'id', message: `Todo with ID ${id} does not exist`, value: id }]
    });
  }
  
  res.json(updatedTodo);
});

router.delete('/:id', validateTodoId, (req: Request, res: Response) => {
  const { id } = req.params;
  const deleted = todoStore.delete(id);
  
  if (!deleted) {
    return res.status(404).json({ 
      error: 'Todo not found',
      details: [{ field: 'id', message: `Todo with ID ${id} does not exist`, value: id }]
    });
  }
  
  res.status(204).send();
});

export { router as todoRoutes };
