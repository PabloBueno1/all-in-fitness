"""Add exercise details

Revision ID: 839a12fc7a29
Revises: c0d42c124e1e
Create Date: 2025-03-09 02:28:42.448616

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic
revision: str = '839a12fc7a29'
down_revision: Union[str, None] = 'c0d42c124e1e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Apply the migration - Add new columns to exercise_types"""
    op.add_column('exercise_types', sa.Column('description', sa.String(), nullable=True))
    op.add_column('exercise_types', sa.Column('category', sa.String(), nullable=True))
    op.add_column('exercise_types', sa.Column('muscles', sa.String(), nullable=True))


def downgrade() -> None:
    """Rollback the migration - Remove columns from exercise_types"""
    op.drop_column('exercise_types', 'muscles')
    op.drop_column('exercise_types', 'category')
    op.drop_column('exercise_types', 'description')
