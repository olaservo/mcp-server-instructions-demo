import { Request, Response, NextFunction } from 'express';

export interface ValidationError {
  field: string;
  message: string;
  value?: any;
}

export class ValidationException extends Error {
  public errors: ValidationError[];

  constructor(errors: ValidationError[]) {
    super('Validation failed');
    this.name = 'ValidationException';
    this.errors = errors;
  }
}

export const validateTodoCreate = (req: Request, res: Response, next: NextFunction) => {
  const errors: ValidationError[] = [];
  const { title, description } = req.body;

  // Validate title
  if (!title) {
    errors.push({ field: 'title', message: 'Title is required' });
  } else if (typeof title !== 'string') {
    errors.push({ field: 'title', message: 'Title must be a string', value: title });
  } else if (title.trim().length === 0) {
    errors.push({ field: 'title', message: 'Title cannot be empty' });
  } else if (title.length > 100) {
    errors.push({ field: 'title', message: 'Title must be 100 characters or less' });
  } else if (/<[^>]*>/g.test(title)) {
    errors.push({ field: 'title', message: 'Title cannot contain HTML tags' });
  }

  // Validate description
  if (description !== undefined && description !== null) {
    if (typeof description !== 'string') {
      errors.push({ field: 'description', message: 'Description must be a string', value: description });
    } else if (description.length > 500) {
      errors.push({ field: 'description', message: 'Description must be 500 characters or less' });
    } else if (/<.*>/g.test(description)) {  // BUG: Inconsistent regex - allows <img> but title rejects it
      errors.push({ field: 'description', message: 'Description cannot contain HTML tags' });
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors
    });
  }

  next();
};

export const validateTodoUpdate = (req: Request, res: Response, next: NextFunction) => {
  const errors: ValidationError[] = [];
  const { title, description, completed } = req.body;

  // Validate title if provided
  if (title !== undefined) {
    if (typeof title !== 'string') {
      errors.push({ field: 'title', message: 'Title must be a string', value: title });
    } else if (title.trim().length === 0) {
      errors.push({ field: 'title', message: 'Title cannot be empty' });
    } else if (title.length > 100) {
      errors.push({ field: 'title', message: 'Title must be 100 characters or less' });
    } else if (/<[^>]*>/g.test(title)) {
      errors.push({ field: 'title', message: 'Title cannot contain HTML tags' });
    }
  }

  // Validate description if provided
  if (description !== undefined && description !== null) {
    if (typeof description !== 'string') {
      errors.push({ field: 'description', message: 'Description must be a string', value: description });
    } else if (description.length > 500) {
      errors.push({ field: 'description', message: 'Description must be 500 characters or less' });
    } else if (/<[^>]*>/g.test(description)) {
      errors.push({ field: 'description', message: 'Description cannot contain HTML tags' });
    }
  }

  // Validate completed if provided
  if (completed !== undefined && typeof completed !== 'boolean') {
    errors.push({ field: 'completed', message: 'Completed must be a boolean', value: completed });
  }

  if (errors.length > 0) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors
    });
  }

  next();
};

export const validateTodoId = (req: Request, res: Response, next: NextFunction) => {
  const { id } = req.params;

  if (!id || !/^\d+$/.test(id)) {
    return res.status(400).json({
      error: 'Invalid ID format',
      details: [{ field: 'id', message: 'ID must be a positive integer', value: id }]
    });
  }

  // BUG: This allows ID "0" which may not be valid depending on our ID generation strategy
  next();
};
