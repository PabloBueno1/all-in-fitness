"""remove user id from exercisetype

Revision ID: 5c1536d7be4e
Revises: 839a12fc7a29
Create Date: 2025-03-09 05:14:42.381062

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '5c1536d7be4e'
down_revision: Union[str, None] = '839a12fc7a29'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # First, remove any existing foreign key constraints
    with op.batch_alter_table('exercise_types') as batch_op:
        batch_op.drop_constraint('exercise_types_user_id_fkey', type_='foreignkey')
        batch_op.drop_column('user_id')


def downgrade() -> None:
    # Add back the user_id column and its foreign key constraint
    with op.batch_alter_table('exercise_types') as batch_op:
        batch_op.add_column(sa.Column('user_id', sa.Integer(), nullable=True))
        batch_op.create_foreign_key(
            'exercise_types_user_id_fkey',
            'users',
            ['user_id'], ['id']
        )